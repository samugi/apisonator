require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ServiceTest < Test::Unit::TestCase
  def setup
    Storage.instance(true).flushdb
    Memoizer.reset!
  end

  def storage
    Service.storage
  end

  test 'load memoizes the result' do
    Storage.instance.expects(:get).once
    assert_nothing_raised do
      2.times { Service.load('foo') }
    end
  end

  test 'load_id! raises an exception if service does not exist' do
    assert_raise ProviderKeyInvalid do
      Service.load_id!('foo')
    end
  end

  test 'load_id! returns service id if it exists' do
    Service.save!(:provider_key => 'foo', :id => '1001')

    assert_equal '1001', Service.load_id!('foo')
  end

  test 'load! raises an exception if service does not exist' do
    assert_raise ProviderKeyInvalid do
      Service.load!('foo')
    end
  end

  test 'load! returns service if it exists' do
    Service.save!(:provider_key => 'foo', :id => '1001')
    assert_not_nil Service.load!('foo')
  end
end
