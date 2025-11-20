# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://docs.brew.sh/rubydoc/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class BoostPythonCibuildwheel < Formula
  desc "Library for writing Python extensions in C++."
  homepage "https://www.boost.org/"
  url "https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.bz2"
  sha256 "85a33fa22621b4f314f8e85e1a5e2a9363d22e4f4992925d4bb3bc631b5a0c7a"
  license "BSL-1.0"

  bottle do
    root_url "https://cs.uky.edu/~acta225/brew"
    rebuild 2
    sha256 cellar: :any, arm64_tahoe:   "29274f000963d720f601a215a61960a4bd9f0bc86d13200a9a486782a8d4e53a"
    sha256 cellar: :any, arm64_sequoia: "c83ae26c8bfbf5ed44d0f96b5ff2b83d7328cd88a98e76ef28ea95f2b95d2240"
    sha256 cellar: :any, arm64_sonoma:  "be45fb699f5d61aa38a5b20b9a14d9d78d356e4543e4d7fb8eb991850c018a70"
    sha256 cellar: :any, sequoia:       "a5cbb2a24705b3170cf7d21e2833b4e8da7b3ee888cdbbe7b9c79b3eabd4c96e"
  end

  keg_only "it conflicts with other boost packages and is intended for CI only"

  depends_on "python@3.13" => :build
  depends_on "toml2json" => :build

  # depends_on "cmake" => :build

  # Additional dependency
  # resource "" do
  #   url ""
  #   sha256 ""
  # end

  def install
    venv_loc = Pathname(Dir.home) / "cibuildwheel"
    system (Formula["python@3.13"].opt_bin / "python3.13").to_str, "-m", \
           "venv", venv_loc.to_str
    venv_python = venv_loc / "bin/python"
    system venv_python.to_str, "-m", "pip", "install", "cibuildwheel"
    venv_lib = venv_loc / "lib"
    build_platforms_toml = venv_lib.glob("*")[0] / \
                           "site-packages/cibuildwheel/resources/" \
                           "build-platforms.toml"
    build_platform = nil
    Open3.popen3(
      "toml2json",
      build_platforms_toml.to_str,
    ) do |stdin, stdout, stderr, thread|
      stdin.close
      build_platform = JSON.parse(stdout.read)["macos"]
      stderr.read
      raise "Build failed!" if thread.value.exitstatus.positive?
    end
    configs = build_platform["python_configurations"]
    arch = RUBY_PLATFORM.split("-")[0]
    system "./bootstrap.sh"
    system "./b2", "tools/bcp"
    File.open("project-config.jam", "r") do |specific_handle|
      File.open("project-config.jam.generic", "w") do |generic_handle|
        ignore = false
        specific_handle.each_line do |line|
          ignore = (ignore || /^# Python configuration/ =~ line) && \
                   line.strip != ""
          next if ignore

          generic_handle.puts line
        end
      end
    end
    File.delete("project-config.jam")
    configs.each do |config|
      next unless config["identifier"].end_with?(arch)

      ft = ""
      if config["identifier"].start_with?("cp")
        ft = "t" if config["identifier"].include?("t-macos")
        base_path = Pathname(
          "/Library/Frameworks/Python#{ft.upcase}.framework/Versions/",
        ) / config["version"]
      else # if config["identifier"].start_with?("pp")
        archive_filename = Pathname(URI.parse(config["url"])).basename
        base_path = Pathname(Dir.home) / "Library/Caches/cibuildwheel" / \
                    archive_filename.basename(archive_filename.extname)
      end
      python_name = config["identifier"].start_with?("pp") ? "pypy" : "python"
      extended_name = "#{python_name}#{config["version"]}#{ft}"
      bin_path = (base_path / "bin/#{extended_name}").to_str
      include_path = (base_path / "include/#{extended_name}").to_str
      lib_path = (base_path / "lib/#{extended_name}").to_str
      conf_values = [config["version"], bin_path, include_path, lib_path]
      conf_value_str = conf_values.map { |x| "\"#{x}\"" }.join(" : ")
      File.open("project-config.jam.generic", "r") do |generic_handle|
        File.open("project-config.jam", "w") do |specific_handle|
          generic_handle.each_line do |line|
            specific_handle.puts line
            next unless /^project.*$/ =~ line

            specific_handle.puts(<<~EOF

                                  # Python configuration
                                  import python ;
                                  {
                                      using python : #{conf_value_str} ;
                                  }
                                  EOF
                                )
          end
        end
      end
      short_identifier = config["identifier"].split("-")[0]
      system "./b2", "stage", "--clean"
      system "./b2", "stage", "--with-python", \
             "--python-buildid=#{short_identifier}", "link=shared", \
             "variant=release"
    end
    lib.mkdir
    Pathname("stage/lib").glob("*") do |install_file|
      lib.install install_file
    end
    include.mkdir    
    Dir.mktmpdir do |include_tmp|
      tmpd = Pathname(include_tmp)
      system "./dist/bin/bcp", "python", "utility", tmpd.to_str
      include.install (tmpd / "boost").to_str
    end
  end

  test do
    system "true"
  end
end
