module Whitehall
  # Whitehall-specific interface for accessing the Publishing API.
  #
  # This should be used in preference to accessing the API adapter or
  # PublishingApiWorkers directly when publishing or republishing models to the
  # Publishing API.
  #
  # publish and republish raise UnpublishableInstanceError if the model instance
  # is not suitable for publishing to the API.
  class UnpublishableInstanceError < StandardError; end

  class PublishingApi
    def self.publish_async(model_instance, update_type_override=nil, queue_override=nil)
      push_live(model_instance, update_type_override, queue_override)
    end

    def self.save_draft_async(model_instance, update_type_override = nil, queue_override = nil)
      locales_for(model_instance).each do |locale|
        save_draft_translation_async(model_instance, locale, update_type_override, queue_override)
      end
    end

    def self.save_draft_translation_async(model_instance, locale, update_type_override = nil, queue_override = nil)
      PublishingApiDraftWorker.perform_async_in_queue(queue_override, model_instance.class.name, model_instance.id, update_type_override, locale)
    end

    def self.republish_async(model_instance)
      if model_instance.class < Edition
        raise ArgumentError, "Use republish_document_async for republishing Editions"
      end
      push_live(model_instance, 'republish')
    end

    def self.bulk_republish_async(model_instance)
      if model_instance.class < Edition
        raise ArgumentError, "This method does not support Editions"
      end
      push_live(model_instance, 'republish', 'bulk_republishing')
    end

    # Synchronise the published and/or draft documents in publishing-api with
    # the contents of Whitehall's database.
    def self.republish_document_async(document, bulk: false)
      queue = bulk ? 'bulk_republishing' : 'default'
      PublishingApiDocumentRepublishingWorker.perform_async_in_queue(
        queue,
        document.id
      )
    end

    def self.schedule_async(edition)
      return unless served_from_content_store?(edition)
      publish_timestamp = edition.scheduled_publication.as_json
      locales_for(edition).each do |locale|
        base_path = Whitehall.url_maker.public_document_path(edition, locale: locale)
        PublishingApiScheduleWorker.perform_async(base_path, publish_timestamp)
        unless edition.document.published?
          PublishingApiComingSoonWorker.perform_async(edition.id, locale)
                                      # perform_async(base_path, publish_timestamp, locale)
        end
      end
    end

    def self.unschedule_async(edition)
      return unless served_from_content_store?(edition)
      locales_for(edition).each do |locale|
        base_path = Whitehall.url_maker.public_document_path(edition, locale: locale)
        PublishingApiUnscheduleWorker.perform_async(base_path)
        self.publish_gone_async(edition.content_id, nil, nil, locale) unless edition.document.published?
      end
    end

    def self.publish_redirect_async(content_id, destination, locale = I18n.default_locale.to_s)
      PublishingApiRedirectWorker.perform_async(content_id, destination, locale)
    end

    def self.publish_gone_async(content_id, alternative_path, explanation, locale = I18n.default_locale.to_s)
      PublishingApiGoneWorker.perform_async(content_id, alternative_path, explanation, locale)
    end

    def self.publish_withdrawal_async(document_content_id, explanation, locale = I18n.default_locale.to_s)
      PublishingApiWithdrawalWorker.perform_async(document_content_id, explanation, locale)
    end

    def self.unpublish_async(unpublishing)
      PublishingApiUnpublishingWorker.perform_async(unpublishing.id)
    end

    def self.save_draft_redirect_async(base_path, redirects, locale = I18n.default_locale.to_s)
      PublishingApiRedirectWorker.perform_async(
        base_path,
        redirects,
        locale,
        draft: true
      )
    end

    def self.save_draft_gone_async(base_path)
      PublishingApiGoneWorker.perform_async(base_path, draft: true)
    end

    def self.discard_draft_async(edition)
      locales_for(edition).each do |locale|
        PublishingApiDiscardDraftWorker.perform_async(edition.content_id, locale)
      end
    end

    def self.discard_translation_async(edition, locale:)
      PublishingApiDiscardDraftWorker.perform_async(edition.content_id, locale)
    end

    def self.publish_services_and_information_async(organisation_id)
      PublishingApiServicesAndInformationWorker.perform_async(organisation_id)
    end

    def self.locales_for(model_instance)
      if model_instance.respond_to?(:translated_locales) && (locales = model_instance.translated_locales).any?
        locales
      else
        [:en]
      end
    end

    def self.push_live(model_instance, update_type_override=nil, queue_override=nil)
      self.assert_public_edition!(model_instance)
      locales_for(model_instance).each do |locale|
        PublishingApiWorker.perform_async_in_queue(queue_override, model_instance.class.name, model_instance.id, update_type_override, locale)
      end
    end

    def self.served_from_content_store?(edition)
      edition.rendering_app == Whitehall::RenderingApp::GOVERNMENT_FRONTEND
    end

    def self.assert_public_edition!(instance)
      if instance.kind_of?(Edition) && !instance.publicly_visible?
        raise UnpublishableInstanceError, "#{instance.class} with ID #{instance.id} is not publishable"
      end
    end
  end
end
