require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe User do
  def valid_attributes(attributes={})
    {
      :login    => 'simon',
      :password => 'foobarspam',
      :password_confirmation => 'foobarspam'
    }.merge(attributes)
  end

  before(:each) do
    @user = User.new
  end

  describe 'associations' do
    it 'has many contexts' do
      User.should have_many(:contexts).
        with_order('position ASC').
        with_dependent(:delete_all)
    end

    it 'has many projects' do
      User.should have_many(:projects).
        with_order('projects.position ASC').
        with_dependent(:delete_all)
    end

    # TODO: uses fixtures to test those
    it 'has many active_projects' do
      User.should have_many(:active_projects).
        with_order('projects.position ASC').
        with_conditions('state = ?', 'active').
        with_class_name('Project')
    end

    it 'has many active contexts' do
      User.should have_many(:active_contexts).
        with_order('position ASC').
        with_conditions('hide = ?', 'true').
        with_class_name('Context')
    end

    it 'has many todos' do
      User.should have_many(:todos).
        with_order('todos.completed_at DESC, todos.created_at DESC').
        with_dependent(:delete_all)
    end

    it 'has many deferred todos' do
      User.should have_many(:deferred_todos).
        with_order('show_from ASC, todos.created_at DESC').
        with_conditions('state = ?', 'deferred').
        with_class_name('Todo')
    end

    it 'has many completed todos' do
      User.should have_many(:completed_todos).
        with_order('todos.completed_at DESC').
        with_conditions('todos.state = ? and todos.completed_at is not null', 'completed').
        with_include(:project, :context).
        with_class_name('Todo')
    end

    it 'has many notes' do
      User.should have_many(:notes).
        with_order('created_at DESC').
        with_dependent(:delete_all)
    end

    it 'has many taggings' do
      User.should have_many(:taggings)
    end

    it 'has many tags through taggings' do
      User.should have_many(:tags).through(:taggings).with_select('DISTINCT tags.*')
    end

    it 'has one preference' do
      User.should have_one(:preference)
    end
  end

  it_should_validate_presence_of :login
  it_should_validate_presence_of :password
  it_should_validate_presence_of :password_confirmation

  it_should_validate_length_of :password, :within => 5..40
  it_should_validate_length_of :login, :within => 3..80

  it_should_validate_uniqueness_of :login
  it_should_validate_confirmation_of :password

  it 'validates presence of password only when password is required'
  it 'validates presence of password_confirmation only when password is required'
  it 'validates confirmation of password only when password is required'
  it 'validates presence of open_id_url only when using openid'

  it 'accepts only allow auth_type authorized by the admin' do
    Tracks::Config.should_receive(:auth_schemes).exactly(3).times.and_return(%w(database open_id))
    User.new(valid_attributes(:auth_type => 'database')).should_not have(:any).error_on(:auth_type)
    User.new(valid_attributes(:auth_type => 'open_id')).should_not  have(:any).error_on(:auth_type)
    User.new(valid_attributes(:auth_type => 'ldap')).should         have(1).error_on(:auth_type)
  end

  it 'returns login for #to_param' do
    @user.login = 'john'
    @user.to_param.should == 'john'
  end

  it 'has a custom finder to find admin' do
    User.should_receive(:find).with(:first, :conditions => ['is_admin = ?', true])
    User.find_admin
  end

  it 'has a custom finder to find by openid url'
  it 'knows if there is any user through #no_users_yet? (TODO: better description)'

  describe 'when choosing what do display as a name' do
    it 'displays login when no first name and last name' do
      User.new(valid_attributes).display_name.should == 'simon'
    end

    it 'displays last name when no first name' do
      User.new(valid_attributes(:last_name => 'foo')).display_name.should == 'foo'
    end

    it 'displays first name when no last name' do
      User.new(valid_attributes(:first_name => 'bar')).display_name.should == 'bar'
    end

    it 'displays first name and last name when both specified' do
      User.new(valid_attributes(:first_name => 'foo', :last_name => 'bar')).display_name.should == 'foo bar'
    end
  end

  describe 'authentication' do
    before(:each) do
      @user = User.create!(valid_attributes)
    end

    it 'authenticates user' do
      User.authenticate('simon', 'foobarspam').should == @user
    end

    it 'resets password' do
      @user.update_attributes(
        :password => 'new password',
        :password_confirmation => 'new password'
      )
      User.authenticate('simon', 'new password').should == @user
    end

    it 'does not rehash password after update of login' do
      @user.update_attribute(:login, 'foobar')
      User.authenticate('foobar', 'foobarspam').should == @user
    end

    it 'sets remember token' do
      @user.remember_me
      @user.remember_token.should_not be_nil
      @user.remember_token_expires_at.should_not be_nil
    end

    it 'unsets remember token' do
      @user.remember_me
      @user.remember_token.should_not be_nil
      @user.forget_me
      @user.remember_token.should be_nil
    end

    it 'remembers me default two weeks' do
      before = 2.weeks.from_now.utc
      @user.remember_me
      after = 2.weeks.from_now.utc
      @user.remember_token.should_not be_nil
      @user.remember_token_expires_at.should_not be_nil
      @user.remember_token_expires_at.should be_between(before, after)
    end
  end
end