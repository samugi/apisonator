require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepReportingTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')
  end

  test 'does not authorize when current usage + predicted usage exceeds the limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits' => 3}})
    Resque.run!

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application.id,
                                     :usage        => {'hits' => 2}

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content

    Resque.run!

    assert_equal 3, @storage.get(application_key(@service.id,
                                                 @application.id,
                                                 @metric_id,
                                                 :month, Time.now.getutc.strftime("%Y%m01"))).to_i


    assert_not_authorized 'usage limits are exceeded'
  end

  test 'succeeds when only limits for the metrics not in the predicted usage are exceeded' do
    metric_one_id = @metric_id

    metric_two_id = next_id
    Metric.save(:service_id => @service.id, :id => metric_two_id, :name => 'hacks')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => metric_one_id,
                    :day        => 4)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => metric_two_id,
                    :day        => 4)

    Transactor.report(@provider_key, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits'  => 2,
                                                        'hacks' => 5}})
    Resque.run!

    assert_equal 2, @storage.get(application_key(@service.id,
                                                 @application.id,
                                                 @metric_id,
                                                 :month, Time.now.getutc.strftime("%Y%m01"))).to_i

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application.id,
                                     :usage        => {'hits' => 1}

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content

    Resque.run!

    assert_equal 3, @storage.get(application_key(@service.id,
                                                 @application.id,
                                                 @metric_id,
                                                 :month, Time.now.getutc.strftime("%Y%m01"))).to_i

    assert_authorized
  end

  test 'does not authorize if usage of a parent metric exceeds the limits but only a child metric which does not exceed the limits is in the predicted usage' do
    child_metric_id = next_id
    Metric.save(:service_id => @service.id,
                :parent_id  => @metric_id,
                :id         => child_metric_id,
                :name       => 'queries')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 4)

    Transactor.report(@provider_key, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits'  => 5}})
    Resque.run!

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application.id,
                                     :usage        => {'queries' => 1}

    Resque.run!

    assert_equal 5, @storage.get(application_key(@service.id,
                                                 @application.id,
                                                 @metric_id,
                                                 :month, Time.now.getutc.strftime("%Y%m01"))).to_i


    assert_not_authorized 'usage limits are exceeded'
  end
end
