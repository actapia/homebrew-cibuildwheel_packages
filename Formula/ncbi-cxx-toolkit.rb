# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://docs.brew.sh/rubydoc/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class NcbiCxxToolkit < Formula
  desc "Collection of C++ bioinformatics libraries from the National Center "\
       "for Biotechnology Information (NCBI)"
  homepage "https://github.com/ncbi/ncbi-cxx-toolkit-public"
  url "https://github.com/ncbi/ncbi-cxx-toolkit-public/archive/refs/tags/release/29.6.0.tar.gz"
  sha256 "c370ede357471dfb8872c13b128ea9c16040511ad90d6bce700880a463351792"
  license "NCBI-PD"

  bottle do
    root_url "https://cs.uky.edu/~acta225/brew"
    rebuild 3
    sha256 cellar: :any, arm64_tahoe:   "0539ee6fac5db76a2bd17cc3d88c5f284cf89cd6caea597c50f89f194c568e89"
    sha256 cellar: :any, arm64_sequoia: "09b2a50b835e42cd2d391fae9b8f2360ae38cb057eb805978ef7192dfd9ad3b3"
    sha256 cellar: :any, sequoia:       "c5e97f6f6facb6d7aac5ba0bdf357566edd86c2de479e0297874776c627c061d"
  end

  keg_only "Includes many files that would pollute bin, lib, and so on, and this
           formula is mainly intended for CI anyway."

  depends_on "cmake" => :build
  depends_on "zstd"
  depends_on "lzo"  
  depends_on "boost" => :build
  uses_from_macos "zlib"
  uses_from_macos "pcre"
  uses_from_macos "sqlite"
  uses_from_macos "bzip2"

  # Additional dependency
  # resource "" do
  #   url ""
  #   sha256 ""
  # end

  def install
    # Remove unrecognized options if they cause configure to fail
    # https://docs.brew.sh/rubydoc/Formula.html#std_configure_args-instance_method
    # system "./configure", "--disable-silent-rules", *std_configure_args
    # system "cmake", "-S", ".", "-B", "build", *std_cmake_args
    system "bash", "cmake-configure", "--with-dll", "--with-install=#{prefix}"
    ncbi_include_dir = include / "ncbi-tools++"
    Dir.chdir(Dir.glob("CMake*/build")[0]) do
      system "make", "-j#{ENV.make_jobs}"
      bin.mkpath
      lib.mkpath
      ncbi_include_dir.mkpath
      bin.install Dir["../bin/*"]
      lib.install Dir["../lib/*"]
      ncbi_include_dir.install Dir["../inc/*"]
    end
    Dir.chdir("include") do
      Find.find(".") do |f|
        if File.directory?(f)
          if File.basename(f) == ".svn"
            File.prune
          else
            dir = ncbi_include_dir / f
            dir.mkpath
          end
        else
          dn = File.dirname(f)
          dir = ncbi_include_dir / dn
          dir.install f
        end
      end
    end
  end

  patch do
    # This patch enables the C++ toolkit to be built in parallel with CMake by
    # adding missing dependencies to certain CMake files.
    url "https://raw.githubusercontent.com/actapia/manylinux_packages/refs/heads/main/ncbi-cxx-toolkit/rpm/ncbi-cxx-toolkit-parallel-cmake.patch"
    sha256 "0be42aa71f58a7d1bb0459f72f24e9384ee26c6f5b434e8cc72bce5c9e867e5d"
  end

  patch do
    # This patch removes zlib's unnecessary fallback fdopen #define, which can
    # cause problems with new macOS compilers.
    url "https://raw.githubusercontent.com/actapia/manylinux_packages/refs/heads/main/ncbi-cxx-toolkit/brew/ncbi-cxx-toolkit-no-fdopen.patch"
    sha256 "1c4ca6b836159fc99061a56ba3f5cd1e9241b008fd8b33748b52144925f91773"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test ncbi-cxx-toolkit-public`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system bin/"program", "do", "something"`.
    system "true"
  end
end
