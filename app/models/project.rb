class Project < ActiveRecord::Base
  after_create :set_path, :init
  after_destroy :deletefiles
  
  belongs_to :user

  validates :name, :presence => true, uniqueness: { scope: :user }

  # get the last update time
  # of the images in the project
  def last_updated
    repo = Grit::Repo.init_bare_or_open(File.join(path , '.git'))
    repo.commits.first.commited_date
  end

  # Delete all the files and directories associated with the project
  def deletefiles
    FileUtils.rm_rf(self.path)
  end

  # Return linkable url of an image
  def imageurl(imagename)
    File.join(self.satellitedir,imagename).gsub("public","")
  end

  # Get the URL of the project
  def urlbase
    urlbase = File.join "/#{user.username}", self.name.gsub(" ", "%20")
    if self.private
      File.join(urlbase, self.uniqueurl)
    else
      urlbase
    end
  end

  # Return the bare repo
  def barerepo
    Rugged::Repository.new(self.barerepopath)
  end

  # Return the satellite repo
  def satelliterepo
    Rugged::Repository.new(self.satelliterepopath)
  end

  # Get the path of the bare repo
  def barerepopath
    File.join self.path , 'repo.git'
  end

  # Get the path of the satelliterepo
  def satelliterepopath
    File.join self.path , 'satellite' , '.git'
  end

  # Get the path of the satelite directory. This is useful to link to images
  def satellitedir
    File.join self.path , 'satellite'
  end

  # Push the existing contents of the satellite repo to the bare repo
  def pushtobare
    barerepo = Rugged::Repository.new(self.barerepopath)
    satelliterepo = Rugged::Repository.new(self.satelliterepopath)
    remote = Rugged::Remote.lookup(satelliterepo,'origin')
    unless remote 
      remote = Rugged::Remote.add(satelliterepo,'origin',barerepo.path)
    end
    remote.push(["refs/heads/master"])
  end

  private
  def set_path
    #TODO - let basedir for repos be set in app config
    user = User.find(self.user_id)
    self.path = File.join 'public', 'data', 'repos', user.id.to_s, self.id.to_s
    logger.debug "setting path - path: #{self.path}"
    self.save
  end

  # Path : public/data/repos/user_id/project_id
  # Bare Repository Path : public/data/repos/user_id/project_id/repo.git
  # Satellite Repository Path : public/data/repos/user_id/project_id/satellite/.git
  def init
    logger.debug "Initing repo path: #{path}"
    unless File.exists? self.path
      #barepath = File.join self.path , 'repo.git'
      #satellitepath = File.join self.path , 'satellite' , '.git'
      Rugged::Repository.init_at(self.barerepopath, :bare)
      Rugged::Repository.clone_at(self.barerepopath,self.satelliterepopath)
       
      #Grit::Repo.init_bare(gitpath)
      #bare_repo = Grit::Git.new (File.join (path + "_bare"), '.git')
      #bare_repo.clone({}, gitpath, (File.join (path.to_s + "_bare"), '.git'))
    end
  end

end
