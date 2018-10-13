import json
import os
import sys
import requests
import adal

log_file = open('{}/tmp/omsresults.out'.format(os.getcwd()), 'a+')

def write_log_command(cmd):
    print(cmd)
    log_file.write(cmd + '\n')
    log_file.write('=' * 40)
    log_file.write('\n')
    return

def write_log_output(out):
    if(type(out) != str): out=str(out)
    log_file.write(out + '\n')
    log_file.write('-' * 80)
    log_file.write('\n')
    return

def check_e2e(hostname):
    with open('/home/temp/omsfiles/_parameters.json', 'r') as f:
        parameters = f.read()
    parameters = json.loads(parameters)

    authority_url = parameters['authority host URL'] + '/' + parameters['tenant']

    context = adal.AuthenticationContext(authority_url)
    token = context.acquire_token_with_client_credentials(
                parameters['resource'],
                parameters['id'],
                parameters['secret'])

    head = {'Authorization': 'Bearer ' + token['accessToken']}

    subscription = parameters['subscription']
    resource_group = parameters['resource group']
    workspace = parameters['workspace name']

    url = ('https://management.azure.com/subscriptions/{}/resourcegroups/{}/'
           'providers/Microsoft.OperationalInsights/workspaces/{}/api/'
           'query?api-version=2017-01-01-preview').format(subscription, resource_group, workspace)

    sources = ['Syslog', 'Perf', 'Heartbeat', 'ApacheAccess_CL', 'MySQL_CL'] # custom ?

    for s in sources:
        query = '%s | where Computer == \'%s\' | take 1' % (s, hostname)
        timespan = 'PT1H'
        r = requests.post(url, headers=head, json={'query':query,'timespan':timespan})

        if r.status_code == requests.codes.ok:
            r = (json.loads(r.text)['Tables'])[0]
            if len(r['Rows']) < 1:
                out = 'Failure: no logs found for {}'.format(s)
            else:
                out = 'Success: logs found for {}'.format(s)

        else:
            out = 'Failure: query request failure with code {} and message {}'.format(r.status_code, json.loads(r.text)['error']['message'])

        cmd = 'Verifying data from computer {} and source {}'.format(computer, s)
        write_log_command(cmd)
        write_log_output(out)

def main():
    check_e2e()

if __name__ == '__main__' :
    main()
