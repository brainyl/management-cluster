"""Root teardown refuses unsafe scope before deleting anything."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('root_teardown', Path(__file__).resolve().parents[1]/'scripts/teardown.py')
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)


class RootTeardownSafety(unittest.TestCase):
    def setUp(self):
        t.ARGS = SimpleNamespace(root_application='control-plane-root')
        t.REGION = 'us-west-2'

    def guard(self, **kwargs):
        data = dict(apps=[], managed=[], composites=[], ingresses=[], pvcs=[])
        data.update(kwargs)
        t.guard_kubernetes(**data)

    def test_foundation_without_crds_is_allowed(self):
        self.guard()

    def test_additional_application_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'Additional Argo'):
            self.guard(apps=[{'metadata':{'name':'another-layer'}}])

    def test_automated_root_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'automatic sync'):
            self.guard(apps=[{'metadata':{'name':'control-plane-root'}, 'spec':{'syncPolicy':{'automated':{'prune':True}}}}])

    def test_unknown_cloud_resource_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'Additional Crossplane'):
            self.guard(managed=[{'kind':'VPC','metadata':{'name':'child-vpc'}}])

    def test_composites_and_storage_are_rejected(self):
        for field in ('composites', 'pvcs'):
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                self.guard(**{field:[{}]})

    def test_credential_retention_and_wrong_region_are_rejected(self):
        item = {'kind':'Secret', 'metadata':{'name':'github-org-credentials'},
                'spec':{'forProvider':{'name':'github-org-credentials','region':'us-west-2'}}}
        self.guard(managed=[item])
        item['spec']['managementPolicies']=['Observe']
        with self.assertRaisesRegex(RuntimeError, 'retains'):
            self.guard(managed=[item])
        del item['spec']['managementPolicies']
        item['spec']['forProvider']['region']='us-east-2'
        with self.assertRaisesRegex(RuntimeError, 'region'):
            self.guard(managed=[item])

    def test_destroy_plan_refuses_creation_and_foreign_scope(self):
        for address, actions in [('module.eks.aws_eks_cluster.x',['create']),('aws_s3_bucket.other',['delete'])]:
            with self.subTest(address=address), self.assertRaises(RuntimeError):
                t.review_changes({'resource_changes':[{'address':address,'change':{'actions':actions}}]})
        self.assertEqual(len(t.review_changes({'resource_changes':[{'address':'module.eks.aws_eks_cluster.x','change':{'actions':['delete']}}]})),1)

    def test_only_foundation_state_uses_targeted_destroy(self):
        self.assertEqual(t.destroy_targets(['module.vpc.aws_vpc.x', 'module.eks.aws_eks_cluster.x']),
                         ['-target=module.vpc', '-target=module.eks'])
        self.assertEqual(t.destroy_targets(['module.vpc.aws_vpc.x', 'module.argocd.helm_release.argocd']), [])
        self.assertEqual(t.destroy_targets([]), [])

    def test_audit_retries_cloud_deletion_but_not_scope_errors(self):
        with patch.object(t, 'verify_once', side_effect=[RuntimeError('Root EIP remains'), None]) as check, patch.object(t.time, 'sleep') as sleep:
            t.verify()
            self.assertEqual(check.call_count, 2)
            sleep.assert_called_once_with(15)
        with patch.object(t, 'verify_once', side_effect=RuntimeError('Checkpoint account/region mismatch')), patch.object(t.time, 'sleep') as sleep:
            with self.assertRaisesRegex(RuntimeError, 'mismatch'):
                t.verify()
            sleep.assert_not_called()

    def test_stale_preparation_is_rejected(self):
        import json
        import tempfile
        with tempfile.TemporaryDirectory() as directory, patch.object(t, 'PRIVATE', Path(directory)), patch.object(t, 'tf', return_value={'lineage':'root', 'serial':3}):
            (Path(directory)/'prepared').write_text(json.dumps({'lineage':'root', 'serial':2}))
            with self.assertRaisesRegex(RuntimeError, 'state changed'):
                t.require_prepared_state()

    def test_unexpected_ingress_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'ingress'):
            self.guard(ingresses=[{'metadata':{'name':'another-app'}}])

    def test_plan_and_apply_require_preparation(self):
        with patch.object(t,'PRIVATE',Path('/nonexistent-root-teardown-checkpoint')), patch.object(t,'run') as run:
            for action in (t.plan,t.apply):
                with self.assertRaisesRegex(RuntimeError,'prepare'):
                    action()
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
