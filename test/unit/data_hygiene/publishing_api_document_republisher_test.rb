require 'test_helper'

class DataHygiene::PublishingApiDocumentRepublisherTest < ActiveSupport::TestCase
  test "republishes a model to the Publishing API" do
    case_study = create(:published_case_study)
    presenter  = PublishingApiPresenters.presenter_for(case_study, update_type: "republish")
    WebMock.reset!

    expected_requests = [
      stub_publishing_api_put_content(presenter.content_id, presenter.content),
      stub_publishing_api_put_links(presenter.content_id, links: presenter.links),
      stub_publishing_api_publish(presenter.content_id, locale: 'en', update_type: 'republish')
    ]

    DataHygiene::PublishingApiDocumentRepublisher.new(CaseStudy, NullLogger.instance).perform

    assert_all_requested(expected_requests)
  end

  test "rejects a scope if passed in" do
    assert_raise ArgumentError do
      DataHygiene::PublishingApiDocumentRepublisher.new(CaseStudy.all)
    end
  end

  test "rejects a class that isn't a subclass of Edition" do
    assert_raise ArgumentError do
      DataHygiene::PublishingApiDocumentRepublisher.new(Organisation)
    end
  end
end
