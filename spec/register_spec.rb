# encoding: UTF-8

require_relative 'spec_helper'

describe 'openstack-identity::default' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) { runner.converge(described_recipe) }
    let(:events) { Chef::EventDispatch::Dispatcher.new }
    let(:cookbook_collection) { Chef::CookbookCollection.new([]) }
    let(:run_context) { Chef::RunContext.new(node, cookbook_collection, events) }

    describe 'tenant_create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('tenant1',
                                                          run_context)
        r.tenant_name('tenant1')
        r.tenant_description('tenant1 Tenant')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when tenant does not already exist' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
          allow(provider).to receive(:identity_command)
            .with(resource, 'tenant-create',
                  'name' => 'tenant1',
                  'description' => 'tenant1 Tenant',
                  'enabled' => true)
            .and_return(true)
        end

        it 'should create a tenant' do
          provider.run_action(:create_tenant)

          expect(resource).to be_updated
        end
      end

      context 'when tenant does already exist' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
        end

        it 'should not create a tenant' do
          provider.run_action(:create_tenant)

          expect(resource).to_not be_updated
        end
      end

      context 'when keystone tenant command fails' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_raise('Error!')
        end

        it 'should raise error' do
          expect { provider.run_action(:create_tenant) }.to raise_error
        end
      end
    end

    describe 'service_create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('service1',
                                                          run_context)
        r.service_type('compute')
        r.service_name('service1')
        r.service_description('service1 Service')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'catalog.backend is sql' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'sql'
        end

        context 'when service does not already exist' do
          it 'should create a service' do
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
            allow(provider).to receive(:identity_command)
              .with(resource, 'service-create',
                    'type' => 'compute',
                    'name' => 'service1',
                    'description' => 'service1 Service')
              .and_return(true)
            provider.run_action(:create_service)

            expect(resource).to be_updated
          end
        end

        context 'when service does already exist' do
          before do
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            allow(provider).to receive(:service_need_updated?)
              .with(resource)
              .and_return(false)
          end

          it 'should not create a service' do
            provider.run_action(:create_service)
            expect(resource).to_not be_updated
          end
        end

        context 'when service does already exist and needs to be updated' do
          before do
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            allow(provider).to receive(:service_need_updated?)
              .with(resource)
              .and_return(true)
            allow(provider).to receive(:identity_command)
              .with(resource, 'service-delete',
                    '' => '1234567890ABCDEFGH')
            allow(provider).to receive(:identity_command)
              .with(resource, 'service-create',
                    'type' => 'compute',
                    'name' => 'service1',
                    'description' => 'service1 Service')
          end

          it 'should update the service' do
            provider.run_action(:create_service)
            expect(resource).to be_updated
          end
        end

        context '#service_need_updated?, when service exists and does not need to be updated' do
          before do
            output = ' | 1234567890ABCDEFGH | service1 | compute | service1 Service '
            output_array = [{ 'id' => '1234567890ABCDEFGH', 'name' => 'service1', 'type' => 'compute', 'description' => 'service1 Service' }]
            allow(provider).to receive(:identity_command)
              .with(resource, 'service-list', {})
              .and_return(output)
            allow(provider).to receive(:prettytable_to_array)
              .with(output)
              .and_return(output_array)
          end

          it 'service should not be updated' do
            expect(
              provider.send(:service_need_updated?, resource)
            ).to eq(false)
          end
        end

        context '#service_need_updated?, when service exists and needs to be updated' do
          before do
            output = ' | 1234567890ABCDEFGH | service11 | compute | service11 Service '
            output_array = [{ 'id' => '1234567890ABCDEFGH', 'name' => 'service11', 'type' => 'compute', 'description' => 'service11 Service' }]
            allow(provider).to receive(:identity_command)
              .with(resource, 'service-list', {})
              .and_return(output)
            allow(provider).to receive(:prettytable_to_array)
              .with(output)
              .and_return(output_array)
          end
          it 'service should be updated' do
            expect(
              provider.send(:service_need_updated?, resource)
            ).to eq(true)
          end
        end
      end

      context 'when keystone service command fails' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'service', 'name', 'compute')
            .and_raise('Error!')
        end

        it 'should raise error' do
          expect { provider.run_action(:create_service) }.to raise_error
        end
      end

      context 'catalog.backend is templated' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end

        it 'should not create a service if using a templated backend' do
          provider.run_action(:create_service)
          expect(resource).to_not be_updated
        end
      end
    end

    describe 'endpoint_create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('endpoint1',
                                                          run_context)
        r.endpoint_region('Region One')
        r.service_type('compute')
        r.endpoint_publicurl('http://public')
        r.endpoint_internalurl('http://internal')
        r.endpoint_adminurl('http://admin')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'catalog.backend is sql' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'sql'
        end

        context 'when endpoint does not already exist' do
          before do
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'endpoint', 'service_id', '1234567890ABCDEFGH')
            allow(provider).to receive(:identity_command)
              .with(resource, 'endpoint-create',
                    'region' => 'Region One',
                    'service_id' => '1234567890ABCDEFGH',
                    'publicurl' => 'http://public',
                    'internalurl' => 'http://internal',
                    'adminurl' => 'http://admin')
          end

          it 'should create an endpoint' do
            provider.run_action(:create_endpoint)
            expect(resource).to be_updated
          end
        end

        context 'when endpoint does already exist' do
          before do
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'endpoint', 'service_id', '1234567890ABCDEFGH')
              .and_return('0987654321HGFEDCBA')
            allow(provider).to receive(:endpoint_need_updated?)
              .with(resource, 'service_id', '1234567890ABCDEFGH')
              .and_return(false)
          end

          it 'should not update an endpoint' do
            provider.run_action(:create_endpoint)
            expect(resource).not_to be_updated
          end
        end

        context 'when endpoint does already exist and need to be updated' do
          before do
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'service', 'type', 'compute')
              .and_return('1234567890ABCDEFGH')
            allow(provider).to receive(:identity_uuid)
              .with(resource, 'endpoint', 'service_id', '1234567890ABCDEFGH')
              .and_return('0987654321HGFEDCBA')
            allow(provider).to receive(:endpoint_need_updated?)
              .with(resource, 'service_id', '1234567890ABCDEFGH')
              .and_return(true)
            allow(provider).to receive(:identity_command)
              .with(resource, 'endpoint-delete',
                    '' => '0987654321HGFEDCBA')
            allow(provider).to receive(:identity_command)
              .with(resource, 'endpoint-create',
                    'region' => 'Region One',
                    'service_id' => '1234567890ABCDEFGH',
                    'publicurl' => 'http://public',
                    'internalurl' => 'http://internal',
                    'adminurl' => 'http://admin')
          end

          it 'should update an endpoint' do
            provider.run_action(:create_endpoint)
            expect(resource).to be_updated
          end
        end

        context '#identity_uuid, when service id for Region One already exist' do
          before do
            output = ' | 000d9c447d124754a197fc612f9d63d7 | Region One | http://public | http://internal |  http://admin | f9511a66e0484f3dbd1584065e8bab1c '
            output_array = [{ 'id' => '000d9c447d124754a197fc612f9d63d7', 'region' => 'Region One', 'publicurl' => 'http://public', 'internalurl' => 'http://internal', 'adminurl' => 'http://admin', 'service_id' => 'f9511a66e0484f3dbd1584065e8bab1c' }]
            allow(provider).to receive(:identity_command)
              .with(resource, 'endpoint-list', {})
              .and_return(output)
            allow(provider).to receive(:prettytable_to_array)
              .with(output)
              .and_return(output_array)
          end

          it 'endpoint uuid should be returned' do
            expect(
              provider.send(:identity_uuid, resource, 'endpoint',
                            'service_id', 'f9511a66e0484f3dbd1584065e8bab1c')
            ).to eq('000d9c447d124754a197fc612f9d63d7')
          end
        end

        context '#identity_uuid, when service id for Region Two does not exist' do
          before do
            output = ' | 000d9c447d124754a197fc612f9d63d7 | Region Two | http://public | http://internal |  http://admin | f9511a66e0484f3dbd1584065e8bab1c '
            output_array = [{ 'id' => '000d9c447d124754a197fc612f9d63d7', 'region' => 'Region Two', 'publicurl' => 'http://public', 'internalurl' => 'http://internal', 'adminurl' => 'http://admin', 'service_id' => 'f9511a66e0484f3dbd1584065e8bab1c' }]
            allow(provider).to receive(:identity_command)
              .with(resource, 'endpoint-list', {})
              .and_return(output)
            allow(provider).to receive(:prettytable_to_array)
              .with(output)
              .and_return(output_array)
          end

          it 'no endpoint uuid should be returned' do
            expect(
              provider.send(:identity_uuid, resource, 'endpoint',
                            'service_id', 'f9511a66e0484f3dbd1584065e8bab1c')
            ).to eq(nil)
          end
        end

        context '#search_uuid' do
          it 'required_hash only has key id' do
            output_array = [{ 'id' => '000d9c447d124754a197fc612f9d63d7', 'region' => 'Region Two', 'publicurl' => 'http://public' }]
            expect(
              provider.send(:search_uuid, output_array, 'id',
                            'id' => '000d9c447d124754a197fc612f9d63d7')
            ).to eq('000d9c447d124754a197fc612f9d63d7')
            expect(
              provider.send(:search_uuid, output_array, 'id', 'id' => 'abc')
            ).to eq(nil)
          end

          it 'required_hash has key id and region' do
            output_array = [{ 'id' => '000d9c447d124754a197fc612f9d63d7', 'region' => 'Region Two', 'publicurl' => 'http://public' }]
            expect(
              provider.send(:search_uuid, output_array, 'id',
                            'id' => '000d9c447d124754a197fc612f9d63d7',
                            'region' => 'Region Two')
            ).to eq('000d9c447d124754a197fc612f9d63d7')
            expect(
              provider.send(:search_uuid, output_array, 'id',
                            'id' => '000d9c447d124754a197fc612f9d63d7',
                            'region' => 'Region One')
            ).to eq(nil)
            expect(
              provider.send(:search_uuid, output_array, 'id',
                            'id' => '000d9c447d124754a197fc612f9d63d7',
                            'region' => 'Region Two', 'key' => 'value')
            ).to eq(nil)
          end
        end

        context '#endpoint_need_updated?, when endpoint exist and not need to be updated' do
          before do
            output = ' | 000d9c447d124754a197fc612f9d63d7 | Region One | http://public | http://internal |  http://admin | f9511a66e0484f3dbd1584065e8bab1c '
            output_array = [{ 'id' => '000d9c447d124754a197fc612f9d63d7', 'region' => 'Region One', 'publicurl' => 'http://public', 'internalurl' => 'http://internal', 'adminurl' => 'http://admin', 'service_id' => 'f9511a66e0484f3dbd1584065e8bab1c' }]
            allow(provider).to receive(:identity_command)
              .with(resource, 'endpoint-list', {})
              .and_return(output)
            allow(provider).to receive(:prettytable_to_array)
              .with(output)
              .and_return(output_array)
          end

          it 'endpoint should not be updated' do
            expect(
              provider.send(:endpoint_need_updated?, resource,
                            'service_id', 'f9511a66e0484f3dbd1584065e8bab1c')
            ).to eq(false)
          end
        end

        context '#endpoint_need_updated?, when endpoint exist and need to be updated' do
          before do
            output = ' | 000d9c447d124754a197fc612f9d63d7 | Region One | https://public | https://internal |  https://admin | f9511a66e0484f3dbd1584065e8bab1c '
            output_array = [{ 'id' => '000d9c447d124754a197fc612f9d63d7', 'region' => 'Region One', 'publicurl' => 'https://public', 'internalurl' => 'https://internal', 'adminurl' => 'https://admin', 'service_id' => 'f9511a66e0484f3dbd1584065e8bab1c' }]
            allow(provider).to receive(:identity_command)
              .with(resource, 'endpoint-list', {})
              .and_return(output)
            allow(provider).to receive(:prettytable_to_array)
              .with(output)
              .and_return(output_array)
          end

          it 'endpoint should be updated' do
            expect(
              provider.send(:endpoint_need_updated?, resource,
                            'service_id', 'f9511a66e0484f3dbd1584065e8bab1c')
            ).to eq(true)
          end
        end
      end

      context 'catalog.backend is templated' do
        before do
          node.set['openstack']['identity']['catalog']['backend'] = 'templated'
        end

        it 'should not create an endpoint' do
          provider.run_action(:create_endpoint)
          expect(resource).to_not be_updated
        end
      end

      context 'when keystone endpoint command fails' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'service', 'type', 'compute')
            .and_raise('Error!')
        end

        it 'should raise error' do
          expect { provider.run_action(:create_endpoint) }.to raise_error
        end
      end
    end

    describe 'role create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('role1', run_context)
        r.role_name('role1')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when role does not already exist' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
          allow(provider).to receive(:identity_command)
            .with(resource, 'role-create',
                  'name' => 'role1')
        end

        it 'should create a role' do
          provider.run_action(:create_role)
          expect(resource).to be_updated
        end
      end

      context 'when role already exist' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
            .and_return('1234567890ABCDEFGH')
        end

        it 'should not create a role' do
          provider.run_action(:create_role)
          expect(resource).to_not be_updated
        end
      end

      context 'when keystone role command fails' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
            .and_raise('Error!')
        end

        it 'should raise error' do
          expect { provider.run_action(:create_role) }.to raise_error
        end
      end
    end

    describe 'user create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('user1', run_context)
        r.user_name('user1')
        r.tenant_name('tenant1')
        r.user_pass('password')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when user does not already exist' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          allow(provider).to receive(:identity_command)
            .with(resource, 'user-list',
                  'tenant-id' => '1234567890ABCDEFGH')
          allow(provider).to receive(:identity_command)
            .with(resource, 'user-create',
                  'name' => 'user1',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'pass' => 'password',
                  'enabled' => true)
          allow(provider).to receive(:prettytable_to_array)
            .and_return([])
        end

        it 'should create a user' do
          provider.run_action(:create_user)
          expect(resource).to be_updated
        end
      end

      context 'when user already exist with same password' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          allow(provider).to receive(:identity_command)
            .with(resource, 'user-list',
                  'tenant-id' => '1234567890ABCDEFGH')
          allow(provider).to receive(:prettytable_to_array)
            .and_return([{ 'name' => 'user1' }])
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user', 'name', 'user1')
            .and_return('HGFEDCBA0987654321')
          allow(provider).to receive(:identity_command)
            .with(resource, 'token-get', {}, 'user')
        end

        it 'should not create a user' do
          provider.run_action(:create_user)
          expect(resource).to_not be_updated
        end
      end

      context 'when user already exist and changed password' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          allow(provider).to receive(:identity_command)
            .with(resource, 'user-list',
                  'tenant-id' => '1234567890ABCDEFGH')
          allow(provider).to receive(:prettytable_to_array)
            .and_return([{ 'name' => 'user1' }])
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user', 'name', 'user1')
            .and_return('HGFEDCBA0987654321')
          allow(provider).to receive(:identity_command)
            .with(resource, 'token-get', {}, 'user')
            .and_raise('Error!')
          allow(provider).to receive(:identity_command)
            .with(resource, 'user-password-update',
                  'pass' => 'password',
                  '' => 'user1')
        end

        it 'should update user password' do
          provider.run_action(:create_user)
          expect(resource).to be_updated
        end
      end

      describe '#identity_command' do
        it 'should handle false values and long descriptions' do
          allow(provider).to receive(:shell_out)
            .with(['keystone', '--insecure', 'user-create', '--enabled',
                   'false', '--description', 'more than one word'],
                  env: {
                    'OS_SERVICE_ENDPOINT' => nil,
                    'OS_SERVICE_TOKEN' => nil })
            .and_return double('shell_out', exitstatus: 0, stdout: 'good')

          expect(
            provider.send(:identity_command, resource, 'user-create',
                          'enabled' => false,
                          'description' => 'more than one word')
          ).to eq('good')
        end
      end

      context 'when keystone user command fails' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_raise('Error!')
        end

        it 'should raise error' do
          expect { provider.run_action(:create_user) }.to raise_error
        end
      end
    end

    describe 'role grant' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('grant1', run_context)
        r.user_name('user1')
        r.tenant_name('tenant1')
        r.role_name('role1')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when role has not already been granted' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user', 'name', 'user1')
            .and_return('HGFEDCBA0987654321')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
            .and_return('ABC1234567890DEF')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user-role', 'name', 'role1',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'user-id' => 'HGFEDCBA0987654321')
            .and_return('ABCD1234567890EFGH')
          allow(provider).to receive(:identity_command)
            .with(resource, 'user-role-add',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'role-id' => 'ABC1234567890DEF',
                  'user-id' => 'HGFEDCBA0987654321')
        end

        it 'should grant a role' do
          provider.run_action(:grant_role)
          expect(resource).to be_updated
        end
      end

      context 'when role has already been granted' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user', 'name', 'user1')
            .and_return('HGFEDCBA0987654321')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'role', 'name', 'role1')
            .and_return('ABC1234567890DEF')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user-role', 'name', 'role1',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'user-id' => 'HGFEDCBA0987654321')
            .and_return('ABC1234567890DEF')
          allow(provider).to receive(:identity_command)
            .with(resource, 'user-role-add',
                  'tenant-id' => '1234567890ABCDEFGH',
                  'role-id' => 'ABC1234567890DEF',
                  'user-id' => 'HGFEDCBA0987654321')
        end

        it 'should not grant a role' do
          provider.run_action(:grant_role)
          expect(resource).to_not be_updated
        end
      end

      context 'when keystone grant command fails' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_raise('Error!')
        end

        it 'should raise error' do
          expect { provider.run_action(:grant_role) }.to raise_error
        end
      end
    end

    describe 'ec2_credentials create' do
      let(:resource) do
        r = Chef::Resource::OpenstackIdentityRegister.new('ec2', run_context)
        r.user_name('user1')
        r.tenant_name('tenant1')
        r.admin_tenant_name('admintenant1')
        r.admin_user('adminuser1')
        r.admin_pass('password')
        r.identity_endpoint('http://admin')
        r
      end
      let(:provider) do
        Chef::Provider::OpenstackIdentityRegister.new(resource, run_context)
      end

      context 'when ec2 creds have not already been created' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user', 'name', 'user1',
                  'tenant-id' => '1234567890ABCDEFGH')
            .and_return('HGFEDCBA0987654321')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'ec2-credentials', 'tenant', 'tenant1',
                  { 'user-id' => 'HGFEDCBA0987654321' }, 'access')
          allow(provider).to receive(:identity_command)
            .with(resource, 'ec2-credentials-create',
                  { 'user-id' => 'HGFEDCBA0987654321',
                    'tenant-id' => '1234567890ABCDEFGH' },
                  'admin')
          allow(provider).to receive(:prettytable_to_array)
            .and_return([{ 'access' => 'access', 'secret' => 'secret' }])
        end

        it 'should grant ec2 creds' do
          provider.run_action(:create_ec2_credentials)
          expect(resource).to be_updated
        end
      end

      context 'when ec2 creds have not already been created' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_return('1234567890ABCDEFGH')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'user', 'name', 'user1',
                  'tenant-id' => '1234567890ABCDEFGH')
            .and_return('HGFEDCBA0987654321')
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'ec2-credentials', 'tenant', 'tenant1',
                  { 'user-id' => 'HGFEDCBA0987654321' }, 'access')
            .and_return('ABC1234567890DEF')
        end

        it 'should grant ec2 creds if they already exist' do
          provider.run_action(:create_ec2_credentials)
          expect(resource).to_not be_updated
        end
      end

      context 'when keystone user command fails' do
        before do
          allow(provider).to receive(:identity_uuid)
            .with(resource, 'tenant', 'name', 'tenant1')
            .and_raise('Error!')
        end

        it 'should raise error' do
          expect { provider.run_action(:create_ec2_credentials) }.to raise_error
        end
      end
    end
  end
end
