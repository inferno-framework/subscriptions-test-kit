RSpec.shared_context('when testing a suite') do |suite_id|
  let(:suite) { Inferno::Repositories::TestSuites.new.find(suite_id) }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:validation_url) { "#{ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')}/validate" }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite_id) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name)
      )
    end

    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  def find_test(runnable, id)
    # target has the search id as a suffix of the parent's id
    target_id = runnable.parent.nil? ? id : "#{runnable.parent.id}-#{id}"
    return runnable if runnable.id == target_id

    runnable.children.each do |entity|
      found = find_test(entity, id)
      return found unless found.nil?
    end

    nil
  end
end
