# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password
  
  
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user
  before_filter :require_user
  
  private
  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end
  
  def require_user
    unless current_user
      store_location
      flash[:error] = "You must be logged in to access this page"
      redirect_to new_user_session_url
      return false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:notice] = "You must be logged out to access this page"
      redirect_to account_url
      return false
    end
  end
  
  def require_event_session
    if !current_event || current_event != @event
      store_location
      flash[:error] = "Please log in to this event"
      redirect_to new_event_event_session_path(@event)
      return false
    end
  end
  
  
  def current_event_session
    return @current_event_session if defined?(@current_event_session)
    @current_event_session = EventSession.find
  end

  def current_event
    return @current_event if defined?(@current_event)
    @current_event = current_event_session && current_event_session.event
  end
  
  def store_location
    session[:return_to] = request.request_uri
  end
  
  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end
  protected
end
