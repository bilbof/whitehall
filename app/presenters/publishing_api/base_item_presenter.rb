module PublishingApi
  class BaseItemPresenter
    attr_accessor :item, :title, :locale

    def initialize(item, title: nil, locale: I18n.locale.to_s)
      self.item = item
      self.title = title || item.title
      self.locale = locale
    end

    def base_attributes
      {
        title: title,
        locale: locale,
        publishing_app: "whitehall",
        redirects: [],
      }
    end
  end
end
