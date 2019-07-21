require 'rails_helper'

describe Cenit::ActiveTenant do

  let! :active_tenant do
    Cenit::ActiveTenant
  end

  let! :first_tenant do
    Tenant.where(name: User.current.email).first
  end

  let! :second_tenant do
    Tenant.find_or_create_by(name: 'Second')
  end

  before :each do
    active_tenant.clean_all
  end

  context "with adapter independent behavior" do

    it 'it clean all active tenants' do
      expect(active_tenant.total_count).to be 0
      active_tenant.inc_tasks_for_current
      expect(active_tenant.total_count).to be > 0
      active_tenant.clean_all
      expect(active_tenant.total_count).to be 0
    end

    it 'increments active count when increment for a tenant' do
      active_tenant.inc_tasks_for(first_tenant)
      expect(active_tenant.active_count).to be 1

      active_tenant.inc_tasks_for(second_tenant)
      expect(active_tenant.active_count).to be 2
    end

    it 'increments tenant tasks' do
      n = 10
      counter = 0
      n.times do
        expect(active_tenant.tasks_for(first_tenant)).to be counter
        active_tenant.inc_tasks_for(first_tenant)
        counter += 1
      end
      expect(active_tenant.tasks_for(first_tenant)).to be n
    end

    it 'decrements tenant tasks' do
      n = 10
      n.times { active_tenant.inc_tasks_for(first_tenant) }
      while n > 0
        active_tenant.dec_tasks_for(first_tenant)
        n -= 1
        expect(active_tenant.tasks_for(first_tenant)).to be n
      end
    end

    it 'iterates over all active tenants' do
      active_tenant.inc_tasks_for(first_tenant)
      active_tenant.inc_tasks_for(second_tenant)
      tenant_ids = []
      active_tenant.each do |active_tenant|
        tenant_ids << active_tenant[:tenant_id].to_s
      end
      expect(tenant_ids).to contain_exactly(first_tenant.id.to_s, second_tenant.id.to_s)
    end

    it 'returns the proper active tenant information' do
      first_tasks = 1 + rand(9)
      second_tasks = 1 + rand(9)
      first_tasks.times { active_tenant.inc_tasks_for(first_tenant) }
      second_tasks.times { active_tenant.inc_tasks_for(second_tenant) }
      expect(active_tenant.to_hash).to(
        contain_exactly(*{
          first_tenant.id.to_s => first_tasks,
          second_tenant.id.to_s => second_tasks
        }.to_a))
    end

    it 'sets custom tenant tasks counter' do
      tasks = 1 + rand(9);
      active_tenant.set_tasks(tasks, first_tenant)
      expect(active_tenant.tasks_for(first_tenant)).to be tasks
    end

    it 'includes only positive counters in active count' do
      active_tenant.set_tasks(0, first_tenant)
      active_tenant.set_tasks(1, second_tenant)
      expect(active_tenant.active_count).to be 1
    end

    it 'includes all counters in total count' do
      active_tenant.set_tasks(0, first_tenant)
      active_tenant.set_tasks(1, second_tenant)
      expect(active_tenant.total_count).to be 2
    end

    it 'cleans only non positive counters' do
      active_tenant.set_tasks(0, first_tenant)
      active_tenant.set_tasks(1, second_tenant)
      active_tenant.clean
      expect(active_tenant.active_count).to be 1
    end

    it 'cleans all counters' do
      active_tenant.set_tasks(0, first_tenant)
      active_tenant.set_tasks(1, second_tenant)
      active_tenant.clean_all
      expect(active_tenant.total_count).to be 0
    end
  end

  context "when Redis client is present", if: Cenit::Redis.client? do
    it 'uses the Redis adapter' do
      expect(active_tenant.adapter).to be Cenit::ActiveTenant::RedisAdapter
    end
  end

  context "when Redis client is not present", unless: Cenit::Redis.client? do
    it 'uses the Mongoid adapter' do
      expect(active_tenant.adapter).to be Cenit::ActiveTenant::MongoidAdapter
    end
  end
end
