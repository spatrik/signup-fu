class MailTemplate < ActiveRecord::Base
  belongs_to :event
  validates_uniqueness_of :name, :scope => :event_id
  validates_presence_of :body, :subject
  validate :no_payment_reference_without_prefix
  attr_accessor :enable
  
  TEMPLATE_TYPES = [
    ['Signup Confirmation', 'signup_confirmation'],
    ['Payment registered', 'payment_registered'],
    ['Ticket expired', 'ticket_expired'],
    ['Ticket expire reminder', 'ticket_expire_reminder']
  ]
  
  validates_inclusion_of :name, :in => TEMPLATE_TYPES.map(&:last), :message => 'is invalid'
  
  
  def render_body(reply)
    replace_variables(body, reply, reply.event)
  end
  
  def render_subject(reply)
    replace_variables(subject, reply, reply.event)
  end
  
  protected
  def replace_variables(string, reply, event)
    string.gsub!("{{REPLY_NAME}}", reply.name)
    string.gsub!("{{EVENT_NAME}}", event.name)
    string.gsub!("{{PAYMENT_REFERENCE}}", reply.payment_reference)
    string.gsub!("{{PRICE}}", reply.ticket_type.price.to_s)
    string = parse_last_payment_date(string, event)

    string
  end
  
  def parse_last_payment_date(string, event)
    return string if event.payment_time.nil?
    date = Time.now + event.payment_time.days
    string.gsub("{{REPLY_LAST_PAYMENT_DATE}}", date.strftime("%Y-%m-%d"))
  end
  
  def no_payment_reference_without_prefix
    return if event.nil?
    if event.ref_prefix.blank?
      if body.include?("{{PAYMENT_REFERENCE}}")
        errors.add(:body, "can't have a PAYMENT_REFERENCE without a prefix on the event")
      end
      
      if subject.include?("{{PAYMENT_REFERENCE}}")
        errors.add(:subject, "can't have a PAYMENT_REFERENCE without a prefix on the event")
      end
    end
  end
  
end
