require "spec_helper"

feature "authentication" do
  scenario "Working authentication, login and logout" do
    # Logging in and out quickly also triggers a rapid cache warming and expiration issue.
    Calcentral::USER_CACHE_WARMER.stub(:warm).and_return(nil)
    login_with_cas "192517"
    visit "/api/my/status"
    response = JSON.parse(page.body)
    response["is_logged_in"].should be_true
    response["uid"].should == "192517"
    logout_of_cas
    visit "/api/my/status"
    response = JSON.parse(page.body)
    response["is_logged_in"].should be_false
  end

  scenario "Failing authentication" do
    original_logger = OmniAuth.config.logger

    begin
      OmniAuth.config.logger = Logger.new "/dev/null"
      break_cas
      login_with_cas "192517"
      page.status_code.should == 401
      restore_cas "192517"
    ensure
      OmniAuth.config.logger = original_logger
    end
  end
end
