class Cms::ContentController < Cms::BaseController
  
  # Authentication module must have #authenticate method
  include ComfortableMexicanSofa.config.public_auth.to_s.constantize
  
  before_action :load_fixtures
  before_action :load_cms_page,
                :authenticate,
                :only => :render_html
  before_action :load_cms_layout,
                :only => [:render_css, :render_js]
  
  def render_html(status = 200)

    ap "Cms::ContentController.render_html --------------------- OVERRIDE (comfortable_mexican_sofa / app / controllers / cms / content_controller.rb) ---------------------------"

    if CacheHelper.use_memory_cache?(request.env['PATH_INFO'])
      ap "Using the memory cache for #{request.env['PATH_INFO']}"
      render :text => CacheHelper::MemoryCache.instance.get_for_uri(request.env['PATH_INFO'])
      return
    else
      ap "No memory cache hit for #{request.env['PATH_INFO']}"
    end

    children  = Tlobject.where(page_id: @cms_page.id) 
    if children.length == 1
      tl_object = children[0] 
      klass = tl_object.tlobject_type.constantize
      target = klass.find(tl_object.type_id) 
      content_group = ContentGroup.find(tl_object.content_group_id).tlobject.name

      # Only use CMS for: "Application","Chapter","Lesson","Quiz","Link"
      unless ["Application","Chapter","Lesson","Quiz","Link"].include? "#{tl_object.tlobject_type}"
        raise "Unknown Type: #{tl_object.tlobject_type}"
      end

      controller_name = "#{target.type_plural.capitalize}Controller"
      controller_type = controller_name.constantize
      render :text => renderActionInOtherController(controller_type, :show, params, target, content_group, @cms_page)

      return
    end
 
    if @cms_layout = @cms_page.layout
      app_layout = (@cms_layout.app_layout.blank? || request.xhr?) ? false : @cms_layout.app_layout
      render :inline => @cms_page.content, :layout => app_layout, :status => status, :content_type => 'text/html'
    else
      render :text => I18n.t('cms.content.layout_not_found'), :status => 404
    end
  end

 def renderActionInOtherController(controller, action, params, target, content_group, cms_page)
    controller.class_eval{
      def params=(params); @params = params end
      def params; @params end
    }
    c = controller.new

    c.cms_page = cms_page
    c.target = target
    c.content_group = content_group
    
    c.request = @_request
    c.response = @_response
    c.params = params
    c.send(action)
    c.response.body
  end

  # def render_html(status = 200)
  #   if @cms_layout = @cms_page.layout
  #     app_layout = (@cms_layout.app_layout.blank? || request.xhr?) ? false : @cms_layout.app_layout
  #     render :inline => @cms_page.content, :layout => app_layout, :status => status, :content_type => 'text/html'
  #   else
  #     render :text => I18n.t('cms.content.layout_not_found'), :status => 404
  #   end
  # end

  def render_sitemap
    render
  end

  def render_css
    render :text => @cms_layout.css, :content_type => 'text/css'
  end

  def render_js
    render :text => @cms_layout.js, :content_type => 'text/javascript'
  end

protected

  def load_fixtures
    return unless ComfortableMexicanSofa.config.enable_fixtures
    ComfortableMexicanSofa::Fixture::Importer.new(@cms_site.identifier).import!
  end
  
  def load_cms_page
    @cms_page = @cms_site.pages.published.find_by_full_path!("/#{params[:cms_path]}")
    return redirect_to(@cms_page.target_page.url) if @cms_page.target_page
    
  rescue ActiveRecord::RecordNotFound
    # Go to root page if we can't find a match
    flash.now[:error] = 'Could not find page: #{params[:cms_path]}'
    @cms_page = @cms_site.pages.published.find_by_full_path!("/")
    return redirect_to(@cms_page.target_page.url) if @cms_page.target_page

    # if @cms_page = @cms_site.pages.published.find_by_full_path('/404')
    #   render_html(404)
    # else
    #   raise ActionController::RoutingError.new("Page Not Found at: \"#{params[:cms_path]}\"")
    # end
  end

  def load_cms_layout
    @cms_layout = @cms_site.layouts.find_by_identifier!(params[:identifier])
  rescue ActiveRecord::RecordNotFound
    render :nothing => true, :status => 404
  end

end
