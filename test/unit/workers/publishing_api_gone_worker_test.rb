require "test_helper"
require "gds_api/test_helpers/publishing_api_v2"

class PublishingApiGoneWorkerTest < ActiveSupport::TestCase
  include GdsApi::TestHelpers::PublishingApiV2

  setup do
    @uuid = SecureRandom.uuid
  end

  test "publishes a 'gone' item for the supplied content id" do
    request = stub_publishing_api_unpublish(
      @uuid,
      body: {
        type: "gone",
        alternative_path: "alternative_path",
        explanation: "<div class=\"govspeak\"><p><em>why?</em></p>\n</div>",
        locale: "de",
        discard_drafts: true
      }
    )

    PublishingApiGoneWorker.new.perform(@uuid, "alternative_path", "*why?*", "de")

    assert_requested request
  end

  test "passes allow_draft if supplied" do
    request = stub_publishing_api_unpublish(
      @uuid,
      body: {
        type: "gone",
        alternative_path: "alternative_path",
        explanation: "<div class=\"govspeak\"><p><em>why?</em></p>\n</div>",
        locale: "de",
        allow_draft: true
      }
    )

    PublishingApiGoneWorker.new.perform(@uuid, "alternative_path", "*why?*", "de", true)

    assert_requested request
  end

  test "alternative_path is sent without trailing spaces" do
    request = stub_publishing_api_unpublish(
      @uuid,
      body: {
        type: "gone",
        alternative_path: "alternative_path",
        explanation: "<div class=\"govspeak\"><p><em>why?</em></p>\n</div>",
        locale: "de",
        allow_draft: true
      }
    )

    alternative_path_with_trailing_space = "alternative_path "
    PublishingApiGoneWorker.new.perform(@uuid, alternative_path_with_trailing_space, "*why?*", "de", true)

    assert_requested request
  end
end
