#!/usr/bin/env python3
"""Delete and verify only this root management cluster; refuse downstream resources."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / '.local/root-teardown'
ALLOWED_MODULES = ('module.vpc.', 'module.eks.', 'module.argocd.', 'module.crossplane.',
                   'module.external_secrets.', 'module.argocd_pod_identity.',
                   'module.crossplane_pod_identity.', 'module.eso_pod_identity.')
MANAGED_NAMES = {('Secret', 'github-org-credentials'), ('SecretVersion', 'github-org-credentials-version')}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def run(args, *, json_output=False, missing=()):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        if any(code in result.stderr for code in missing):
            return None
        # CLI errors can contain resource/credential values; keep full output private.
        PRIVATE.mkdir(parents=True, exist_ok=True)
        (PRIVATE/'command-error.log').write_text(result.stderr)
        raise RuntimeError(f'{args[0]} command failed; inspect .local/root-teardown/command-error.log privately')
    return json.loads(result.stdout) if json_output else result.stdout.strip()


def aws(service, operation, *args, missing=()):
    return run(['aws', service, operation, *args, '--region', REGION,
                '--output', 'json', '--no-cli-pager'], json_output=True, missing=missing)


def tf(*args, json_output=False):
    return run(['terraform', *args], json_output=json_output)


def kube(*args, json_output=False):
    return run(['kubectl', '--kubeconfig', str(PRIVATE/'kubeconfig'), '--request-timeout=30s',
                *args], json_output=json_output)


def objects(kind):
    return kube('get', kind, '-A', '-o', 'json', json_output=True)['items']


def wait_empty(kind, timeout=1800):
    deadline = time.monotonic() + timeout
    while objects(kind):
        require(time.monotonic() < deadline, f'{kind} deletion timed out; keep controllers running and inspect conditions')
        print(f'Waiting for root {kind} cleanup', flush=True)
        time.sleep(15)


def aws_resources():
    data = tf('show', '-json', json_output=True)
    records = []
    def visit(module):
        for item in module.get('resources', []):
            if item['mode'] == 'managed':
                require(item['address'].startswith(ALLOWED_MODULES), 'Unexpected Terraform resource: '+item['address'])
                if item['type'].startswith('aws_'):
                    records.append({k:item[k] for k in ('address', 'type')} | {'id':item['values'].get('id')})
        for child in module.get('child_modules', []):
            visit(child)
    visit(data.get('values', {}).get('root_module', {}))
    return records


def guard_kubernetes(apps, managed, composites, ingresses, pvcs):
    for app in apps:
        require(app['metadata']['name'] == ARGS.root_application,
                'Additional Argo CD Application exists; use the full lifecycle procedure')
        automated = app['spec'].get('syncPolicy', {}).get('automated')
        require(automated is None or automated.get('enabled') is False,
                'Disable root automatic sync through Terraform before root-only teardown')
        require(not app.get('operation'), 'Wait for the active Argo CD operation')
    for item in managed:
        require((item['kind'], item['metadata']['name']) in MANAGED_NAMES,
                'Additional Crossplane cloud resource exists; root-only teardown refused')
        require(item['spec'].get('deletionPolicy', 'Delete') == 'Delete' and
                bool(set(item['spec'].get('managementPolicies', ['*'])) & {'*', 'Delete'}),
                'Managed resource retains its cloud resource; review its ownership')
        region = item['spec'].get('forProvider', {}).get('region', REGION)
        require(region == REGION, 'Managed resource region does not match root region')
        if item['kind'] == 'Secret':
            require(item['spec']['forProvider'].get('name') == 'github-org-credentials',
                    'Unexpected cloud credential secret name')
    require(not composites, 'Composite resources exist; remove downstream resources first')
    require(not pvcs, 'Persistent workloads exist; remove their storage before root teardown')
    require(all(x['metadata']['name'] == 'argocd-server' for x in ingresses),
            'Unexpected ingress exists; root-only teardown refused')


def prepare():
    records = aws_resources()
    cluster = next((x for x in records if x['type'] == 'aws_eks_cluster'), None)
    require(cluster is not None, 'No root EKS cluster in state; use verify after destruction')
    current = aws('eks', 'describe-cluster', '--name', cluster['id'])['cluster']
    require(current['arn'].split(':')[3] == REGION, 'Root EKS region mismatch')
    require(current['arn'].split(':')[4] == ACCOUNT, 'Root EKS belongs to a different account')
    require(current['status'] == 'ACTIVE', 'Wait for an ACTIVE root cluster before preparation')
    checkpoint = PRIVATE/'inventory.json'
    if checkpoint.exists():
        previous = json.loads(checkpoint.read_text())
        if previous.get('createdAt') != current['createdAt']:
            PRIVATE.rename(PRIVATE.with_name('root-teardown-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f')))
            PRIVATE.mkdir(parents=True)
    (PRIVATE/'prepared').unlink(missing_ok=True)
    vpcs = [x['id'] for x in records if x['type'] == 'aws_vpc']
    run(['aws', 'eks', 'update-kubeconfig', '--name', cluster['id'], '--region', REGION,
         '--kubeconfig', str(PRIVATE/'kubeconfig')])
    # Auto Mode instances can be hidden from EC2 list calls; query live node IDs directly.
    node_ids = sorted({n['spec']['providerID'].rsplit('/', 1)[-1] for n in objects('nodes')
                       if n.get('spec', {}).get('providerID', '').startswith('aws://')})
    instances = aws('ec2', 'describe-instances', '--filters', 'Name=vpc-id,Values='+','.join(vpcs))
    if node_ids:
        direct = aws('ec2', 'describe-instances', '--instance-ids', *node_ids)
        instances['Reservations'].extend(direct['Reservations'])
    instance_ids = sorted({i['InstanceId'] for r in instances['Reservations'] for i in r['Instances']})
    volumes = sorted({b['Ebs']['VolumeId'] for r in instances['Reservations'] for i in r['Instances']
                      for b in i.get('BlockDeviceMappings', []) if 'Ebs' in b})
    data = {'account':ACCOUNT, 'region':REGION, 'cluster':cluster['id'],
            'createdAt':current['createdAt'], 'vpcs':vpcs, 'instances':instance_ids, 'volumes':volumes, 'resources':records}
    if checkpoint.exists():
        old = json.loads(checkpoint.read_text())
        data['resources'] = list({x['address']:x for x in old['resources']+records}.values())
        data['volumes'] = sorted(set(old['volumes']+volumes))
        data['instances'] = sorted(set(old.get('instances', [])+instance_ids))
        data['cloudCredential'] = old.get('cloudCredential', False)
    checkpoint.write_text(json.dumps(data, indent=2))
    resources = set(kube('api-resources', '-o', 'name').splitlines())
    managed = objects('managed') if kube('api-resources', '--categories=managed', '-o', 'name') else []
    composites = objects('composite') if kube('api-resources', '--categories=composite', '-o', 'name') else []
    apps = objects('applications.argoproj.io') if 'applications.argoproj.io' in resources else []
    ingresses = objects('ingresses.networking.k8s.io')
    guard_kubernetes(apps, managed, composites, ingresses, objects('persistentvolumeclaims'))
    saved = json.loads(checkpoint.read_text())
    saved['cloudCredential'] = saved.get('cloudCredential', False) or bool(managed)
    checkpoint.write_text(json.dumps(saved, indent=2))
    require(not [x for x in objects('services') if x['spec']['type'] == 'LoadBalancer'],
            'LoadBalancer Service exists; root-only teardown refused')
    for app in apps:
        kube('delete', 'application', app['metadata']['name'], '-n', app['metadata']['namespace'], '--wait=false')
    if apps:
        wait_empty('applications.argoproj.io')
    for ingress in ingresses:
        kube('delete', 'ingress', ingress['metadata']['name'], '-n', ingress['metadata']['namespace'], '--wait=false')
    wait_empty('ingresses.networking.k8s.io')
    require(not [x for x in objects('services') if x['spec']['type'] == 'LoadBalancer'],
            'LoadBalancer Service exists; remove it with its controller before teardown')
    for kind in ['externalsecrets.external-secrets.io', 'clustersecretstores.external-secrets.io']:
        if kind in resources:
            kube('delete', kind, '--all', '-A', '--wait=false')
            wait_empty(kind)
    for item in sorted(managed, key=lambda x:x['kind'] != 'SecretVersion'):
        kind = item['kind'].lower()+'s.secretsmanager.aws.upbound.io'
        if item['kind'] == 'Secret':
            kube('patch', kind, item['metadata']['name'], '--type=merge', '-p',
                 json.dumps({'spec':{'forProvider':{'recoveryWindowInDays':0}}}))
        kube('delete', kind, item['metadata']['name'], '--wait=false')
        wait_empty(kind)
    if managed:
        wait_empty('managed')
    state = tf('state', 'pull', json_output=True)
    (PRIVATE/'prepared').write_text(json.dumps({'lineage':state['lineage'], 'serial':state['serial']}))
    print('Root-only preparation complete. No downstream resources detected.')


def inventory():
    require((PRIVATE/'prepared').exists(), 'Run prepare before planning destruction')
    data = json.loads((PRIVATE/'inventory.json').read_text())
    require(data['account'] == ACCOUNT and data['region'] == REGION, 'Checkpoint account/region mismatch')
    return data


def review_changes(plan):
    changes = [x for x in plan.get('resource_changes', []) if x['change']['actions'] != ['no-op']]
    require(bool(changes), 'Destroy plan is empty; use verify if already destroyed')
    for item in changes:
        require(item['address'].startswith(ALLOWED_MODULES), 'Unexpected destroy scope: '+item['address'])
        require(item['change']['actions'] in (['delete'], ['read']), 'Destroy plan contains creates or updates')
    return changes


def require_prepared_state():
    state = tf('state', 'pull', json_output=True)
    saved = json.loads((PRIVATE/'prepared').read_text())
    require(saved == {'lineage':state['lineage'], 'serial':state['serial']},
            'Terraform state changed since preparation; run prepare and plan again')


def destroy_targets(addresses):
    foundation = ('module.vpc.', 'module.eks.')
    return ['-target=module.vpc', '-target=module.eks'] if addresses and all(x.startswith(foundation) for x in addresses) else []


def plan():
    inventory()
    require_prepared_state()
    aws_resources()
    require(bool(tf('state', 'list')), 'State is empty; run verify')
    targets = destroy_targets(tf('state', 'list').splitlines())
    if targets:
        print('Foundation-only state: plan destruction of EKS/VPC without absent controller CRDs.')
    result = subprocess.run(['terraform', 'plan', '-destroy', '-input=false', '-no-color',
                             *targets, '-out='+str(PRIVATE/'destroy.tfplan')], cwd=ROOT,
                            stdout=(PRIVATE/'plan.log').open('w'), stderr=subprocess.STDOUT)
    require(result.returncode == 0, 'Destroy plan failed; inspect private plan.log')
    changes = review_changes(tf('show', '-json', str(PRIVATE/'destroy.tfplan'), json_output=True))
    for x in changes:
        print(x['address']+': '+', '.join(x['change']['actions']))
    print('Review the actions above, then run apply. Full plan remains private.')


def apply():
    inventory()
    require_prepared_state()
    require((PRIVATE/'destroy.tfplan').exists(), 'Run plan and review its actions first')
    review_changes(tf('show', '-json', str(PRIVATE/'destroy.tfplan'), json_output=True))
    with (PRIVATE/'apply.log').open('w') as log:
        result = subprocess.run(['terraform', 'apply', '-input=false', '-no-color',
                                 str(PRIVATE/'destroy.tfplan')], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    require(result.returncode == 0, 'Destroy failed; inspect private apply.log, then regenerate plan before retrying')
    require(not tf('state', 'list'), 'Terraform state is not empty')
    print('Root Terraform destruction complete; run verify for AWS cleanup.')


def verify_once():
    data = inventory()
    require(not tf('state', 'list'), 'Terraform state still contains resources')
    require(aws('eks', 'describe-cluster', '--name', data['cluster'], missing=('ResourceNotFoundException',)) is None,
            'Root EKS cluster still exists')
    for vpc in data['vpcs']:
        require(aws('ec2', 'describe-vpcs', '--vpc-ids', vpc, missing=('InvalidVpcID.NotFound',)) is None, 'Root VPC remains')
        nodes = aws('ec2', 'describe-instances', '--filters', 'Name=vpc-id,Values='+vpc)
        require(all(i['State']['Name'] == 'terminated' for r in nodes['Reservations'] for i in r['Instances']), 'Root node remains')
        nats = aws('ec2', 'describe-nat-gateways', '--filter', 'Name=vpc-id,Values='+vpc)
        require(all(x['State'] == 'deleted' for x in nats['NatGateways']), 'Root NAT remains')
        lbs = aws('elbv2', 'describe-load-balancers')['LoadBalancers']
        require(not any(x['VpcId'] == vpc for x in lbs), 'Root load balancer remains')
    for instance in data.get('instances', []):
        observed = aws('ec2', 'describe-instances', '--instance-ids', instance,
                       missing=('InvalidInstanceID.NotFound',))
        require(observed is None or all(i['State']['Name'] == 'terminated'
                for r in observed['Reservations'] for i in r['Instances']), 'Root node remains')
    for volume in data['volumes']:
        require(aws('ec2', 'describe-volumes', '--volume-ids', volume, missing=('InvalidVolume.NotFound',)) is None, 'Root node volume remains')
    for resource in data['resources']:
        kind, value = resource['type'], resource['id']
        if kind == 'aws_eip':
            require(aws('ec2', 'describe-addresses', '--allocation-ids', value, missing=('InvalidAllocationID.NotFound',)) is None, 'Root EIP remains')
        if kind == 'aws_iam_role':
            require(aws('iam', 'get-role', '--role-name', value, missing=('NoSuchEntity',)) is None, 'Root IAM role remains')
        if kind == 'aws_iam_policy':
            require(aws('iam', 'get-policy', '--policy-arn', value, missing=('NoSuchEntity',)) is None, 'Root IAM policy remains')
        if kind == 'aws_iam_openid_connect_provider':
            require(aws('iam', 'get-open-id-connect-provider', '--open-id-connect-provider-arn', value, missing=('NoSuchEntity',)) is None, 'Root OIDC remains')
        if kind == 'aws_kms_key':
            key = aws('kms', 'describe-key', '--key-id', value, missing=('NotFoundException',))
            if key:
                require(key['KeyMetadata']['KeyState'] == 'PendingDeletion', 'Root KMS key is not pending deletion')
                print('Root KMS pending deletion:', key['KeyMetadata']['DeletionDate'])
        if kind == 'aws_cloudwatch_log_group':
            logs = aws('logs', 'describe-log-groups', '--log-group-name-prefix', value)['logGroups']
            require(not any(x['logGroupName'] == value for x in logs), 'Root log group remains')
    if data.get('cloudCredential'):
        require(aws('secretsmanager', 'describe-secret', '--secret-id', 'github-org-credentials', missing=('ResourceNotFoundException',)) is None,
                'Root cloud credential secret remains')
    (PRIVATE/'verified').write_text(datetime.now(timezone.utc).isoformat())
    print('Verified: root EKS, networking, compute/disks, identities and cloud credential absent; Terraform state empty.')


def verify():
    deadline = time.monotonic() + 900
    while True:
        try:
            return verify_once()
        except RuntimeError as error:
            message = str(error)
            transient = 'remains' in message or 'still exists' in message
            if not transient or time.monotonic() >= deadline:
                raise
            print('AWS cleanup still converging: '+message, flush=True)
            time.sleep(15)


def main():
    global ARGS, ACCOUNT, REGION
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['prepare', 'plan', 'apply', 'verify'])
    parser.add_argument('--root-application', default='control-plane-root')
    ARGS = parser.parse_args()
    require(os.environ.get('AWS_PROFILE'), 'Set AWS_PROFILE')
    ACCOUNT = os.environ.get('EXPECTED_AWS_ACCOUNT_ID', '')
    REGION = os.environ.get('AWS_REGION', '')
    require(ACCOUNT.isdigit() and len(ACCOUNT) == 12 and REGION, 'Set EXPECTED_AWS_ACCOUNT_ID and AWS_REGION explicitly')
    os.umask(0o077)
    PRIVATE.mkdir(parents=True, exist_ok=True)
    os.environ['PATH'] = str(ROOT/'.local/bin')+os.pathsep+os.environ['PATH']
    require(aws('sts', 'get-caller-identity')['Account'] == ACCOUNT, 'Wrong AWS account')
    # Terraform and AWS checks use the same explicit provider region.
    os.environ['KUBECONFIG'] = str(PRIVATE/'kubeconfig')
    {'prepare':prepare, 'plan':plan, 'apply':apply, 'verify':verify}[ARGS.stage]()


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
