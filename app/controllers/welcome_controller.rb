class WelcomeController < ApplicationController

  #caches_page :index, :bios, :faq, :contact
  session :off

  def index
  end

  def bios
    @title = 'Speaker Biographies'
  end

  def faq
    @title = 'Frequently Asked Questions'
  end

  def contact
    @title = 'Contact Us'
  end

  def register
    @title = 'Registration'
  end

  def message
    @title = 'Message'
  end
end