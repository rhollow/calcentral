require "spec_helper"

describe CampusUserCoursesProxy do

  it "should be accessible if non-null user" do
    CampusUserCoursesProxy.access_granted?(nil).should be_false
    CampusUserCoursesProxy.access_granted?('211159').should be_true
    client = CampusUserCoursesProxy.new({user_id: '211159'})
    client.get_campus_courses.should_not be_nil
  end

  it "should return pre-populated test enrollments", :if => SakaiData.test_data? do
    client = CampusUserCoursesProxy.new({user_id: '300939'})
    courses = client.get_campus_courses
    courses.empty?.should be_false
    courses.each do |course|
      course[:id].blank?.should be_false
      course[:site_url].blank?.should be_false
      course[:emitter].should == 'Campus'
      course[:name].blank?.should be_false
      course[:color_class].should == 'campus-class'
      ['Student', 'Instructor'].include?(course[:role]).should be_true
      sections = course[:sections]
      sections.length.should be > 0
      sections.each do |section|
        if section[:ccn] == "16171"
          section[:instruction_format].blank?.should be_false
          section[:section_num].blank?.should be_false
          section[:instructors].length.should == 1
          section[:instructors][0][:name].should == "Yu-Hung Lin"
          section[:schedules][0][:schedule].should == "TuTh 2:00P-3:30P"
          section[:schedules][0][:building_name].should == "WHEELER"
        end
      end
    end
  end

end
