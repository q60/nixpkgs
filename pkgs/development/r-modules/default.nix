/* This file defines the composition for CRAN (R) packages. */

{ R, pkgs, overrides }:

let
  inherit (pkgs) cacert fetchurl stdenv lib;

  buildRPackage = pkgs.callPackage ./generic-builder.nix {
    inherit R;
    inherit (pkgs.darwin.apple_sdk.frameworks) Cocoa Foundation;
    inherit (pkgs) gettext gfortran;
  };

  # Generates package templates given per-repository settings
  #
  # some packages, e.g. cncaGUI, require X running while installation,
  # so that we use xvfb-run if requireX is true.
  mkDerive = {mkHomepage, mkUrls}: args:
      lib.makeOverridable ({
        name, version, sha256,
        depends ? [],
        doCheck ? true,
        requireX ? false,
        broken ? false,
        hydraPlatforms ? R.meta.hydraPlatforms
      }: buildRPackage {
    name = "${name}-${version}";
    src = fetchurl {
      inherit sha256;
      urls = mkUrls (args // { inherit name version; });
    };
    inherit doCheck requireX;
    propagatedBuildInputs = depends;
    nativeBuildInputs = depends;
    meta.homepage = mkHomepage (args // { inherit name; });
    meta.platforms = R.meta.platforms;
    meta.hydraPlatforms = hydraPlatforms;
    meta.broken = broken;
  });

  # Templates for generating Bioconductor and CRAN packages
  # from the name, version, sha256, and optional per-package arguments above
  #
  deriveBioc = mkDerive {
    mkHomepage = {name, biocVersion, ...}: "https://bioconductor.org/packages/${biocVersion}/bioc/html/${name}.html";
    mkUrls = {name, version, biocVersion}: [ "mirror://bioc/${biocVersion}/bioc/src/contrib/${name}_${version}.tar.gz"
                                             "mirror://bioc/${biocVersion}/bioc/src/contrib/Archive/${name}/${name}_${version}.tar.gz"
                                             "mirror://bioc/${biocVersion}/bioc/src/contrib/Archive/${name}_${version}.tar.gz" ];
  };
  deriveBiocAnn = mkDerive {
    mkHomepage = {name, ...}: "http://www.bioconductor.org/packages/${name}.html";
    mkUrls = {name, version, biocVersion}: [ "mirror://bioc/${biocVersion}/data/annotation/src/contrib/${name}_${version}.tar.gz" ];
  };
  deriveBiocExp = mkDerive {
    mkHomepage = {name, ...}: "http://www.bioconductor.org/packages/${name}.html";
    mkUrls = {name, version, biocVersion}: [ "mirror://bioc/${biocVersion}/data/experiment/src/contrib/${name}_${version}.tar.gz" ];
  };
  deriveCran = mkDerive {
    mkHomepage = {name, snapshot, ...}: "http://mran.revolutionanalytics.com/snapshot/${snapshot}/web/packages/${name}/";
    mkUrls = {name, version, snapshot}: [ "http://mran.revolutionanalytics.com/snapshot/${snapshot}/src/contrib/${name}_${version}.tar.gz" ];
  };

  # Overrides package definitions with nativeBuildInputs.
  # For example,
  #
  # overrideNativeBuildInputs {
  #   foo = [ pkgs.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     nativeBuildInputs = attrs.nativeBuildInputs ++ [ pkgs.bar ];
  #   });
  # }
  overrideNativeBuildInputs = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        nativeBuildInputs = attrs.nativeBuildInputs ++ value;
      })
    ) overrides;

  # Overrides package definitions with buildInputs.
  # For example,
  #
  # overrideBuildInputs {
  #   foo = [ pkgs.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     buildInputs = attrs.buildInputs ++ [ pkgs.bar ];
  #   });
  # }
  overrideBuildInputs = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        buildInputs = attrs.buildInputs ++ value;
      })
    ) overrides;

  # Overrides package definitions with new R dependencies.
  # For example,
  #
  # overrideRDepends {
  #   foo = [ self.bar ]
  # } old
  #
  # results in
  #
  # {
  #   foo = old.foo.overrideDerivation (attrs: {
  #     nativeBuildInputs = attrs.nativeBuildInputs ++ [ self.bar ];
  #     propagatedNativeBuildInputs = attrs.propagatedNativeBuildInputs ++ [ self.bar ];
  #   });
  # }
  overrideRDepends = overrides: old:
    lib.mapAttrs (name: value:
      (builtins.getAttr name old).overrideDerivation (attrs: {
        nativeBuildInputs = attrs.nativeBuildInputs ++ value;
        propagatedNativeBuildInputs = attrs.propagatedNativeBuildInputs ++ value;
      })
    ) overrides;

  # Overrides package definition requiring X running to install.
  # For example,
  #
  # overrideRequireX [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     requireX = true;
  #   };
  # }
  overrideRequireX = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          requireX = true;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  # Overrides package definition to skip check.
  # For example,
  #
  # overrideSkipCheck [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     doCheck = false;
  #   };
  # }
  overrideSkipCheck = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          doCheck = false;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  # Overrides package definition to mark it broken.
  # For example,
  #
  # overrideBroken [
  #   "foo"
  # ] old
  #
  # results in
  #
  # {
  #   foo = old.foo.override {
  #     broken = true;
  #   };
  # }
  overrideBroken = packageNames: old:
    let
      nameValuePairs = map (name: {
        inherit name;
        value = (builtins.getAttr name old).override {
          broken = true;
        };
      }) packageNames;
    in
      builtins.listToAttrs nameValuePairs;

  defaultOverrides = old: new:
    let old0 = old; in
    let
      old1 = old0 // (overrideRequireX packagesRequireingX old0);
      old2 = old1 // (overrideSkipCheck packagesToSkipCheck old1);
      old3 = old2 // (overrideRDepends packagesWithRDepends old2);
      old4 = old3 // (overrideNativeBuildInputs packagesWithNativeBuildInputs old3);
      old5 = old4 // (overrideBuildInputs packagesWithBuildInputs old4);
      old6 = old5 // (overrideBroken brokenPackages old5);
      old = old6;
    in old // (otherOverrides old new);

  # Recursive override pattern.
  # `_self` is a collection of packages;
  # `self` is `_self` with overridden packages;
  # packages in `_self` may depends on overridden packages.
  self = (defaultOverrides _self self) // overrides;
  _self = { inherit buildRPackage; } //
          import ./bioc-packages.nix { inherit self; derive = deriveBioc; } //
          import ./bioc-annotation-packages.nix { inherit self; derive = deriveBiocAnn; } //
          import ./bioc-experiment-packages.nix { inherit self; derive = deriveBiocExp; } //
          import ./cran-packages.nix { inherit self; derive = deriveCran; };

  # tweaks for the individual packages and "in self" follow

  packagesWithRDepends = {
    FactoMineR = [ self.car ];
    pander = [ self.codetools ];
  };

  packagesWithNativeBuildInputs = {
    arrow = [ pkgs.pkg-config pkgs.arrow-cpp ];
    adimpro = [ pkgs.imagemagick ];
    animation = [ pkgs.which ];
    audio = [ pkgs.portaudio ];
    BayesSAE = [ pkgs.gsl_1 ];
    BayesVarSel = [ pkgs.gsl_1 ];
    BayesXsrc = [ pkgs.readline.dev pkgs.ncurses ];
    bigGP = [ pkgs.mpi ];
    bio3d = [ pkgs.zlib ];
    BiocCheck = [ pkgs.which ];
    Biostrings = [ pkgs.zlib ];
    bnpmr = [ pkgs.gsl_1 ];
    cairoDevice = [ pkgs.gtk2.dev ];
    Cairo = [ pkgs.libtiff pkgs.libjpeg pkgs.cairo.dev pkgs.x11 pkgs.fontconfig.lib ];
    Cardinal = [ pkgs.which ];
    chebpol = [ pkgs.fftw ];
    ChemmineOB = [ pkgs.openbabel pkgs.pkg-config ];
    curl = [ pkgs.curl.dev ];
    data_table = [pkgs.zlib.dev] ++ lib.optional stdenv.isDarwin pkgs.llvmPackages.openmp;
    devEMF = [ pkgs.xorg.libXft.dev pkgs.x11 ];
    diversitree = [ pkgs.gsl_1 pkgs.fftw ];
    EMCluster = [ pkgs.lapack ];
    fftw = [ pkgs.fftw.dev ];
    fftwtools = [ pkgs.fftw.dev ];
    Formula = [ pkgs.gmp ];
    gdtools = [ pkgs.cairo.dev pkgs.fontconfig.lib pkgs.freetype.dev ];
    git2r = [ pkgs.zlib.dev pkgs.openssl.dev pkgs.libssh2.dev pkgs.libgit2 pkgs.pkg-config ];
    GLAD = [ pkgs.gsl_1 ];
    glpkAPI = [ pkgs.gmp pkgs.glpk ];
    gmp = [ pkgs.gmp.dev ];
    graphscan = [ pkgs.gsl_1 ];
    gsl = [ pkgs.gsl_1 ];
    gert = [ pkgs.libgit2 ];
    haven = [ pkgs.libiconv pkgs.zlib.dev ];
    h5vc = [ pkgs.zlib.dev ];
    HiCseg = [ pkgs.gsl_1 ];
    imager = [ pkgs.x11 ];
    iBMQ = [ pkgs.gsl_1 ];
    igraph = [ pkgs.gmp pkgs.libxml2.dev ];
    JavaGD = [ pkgs.jdk ];
    jpeg = [ pkgs.libjpeg.dev ];
    jqr = [ pkgs.jq.dev ];
    KFKSDS = [ pkgs.gsl_1 ];
    kza = [ pkgs.fftw.dev ];
    lwgeom = [ pkgs.gdal pkgs.geos pkgs.proj ];
    magick = [ pkgs.imagemagick.dev ];
    ModelMetrics = lib.optional stdenv.isDarwin pkgs.llvmPackages.openmp;
    mvabund = [ pkgs.gsl_1 ];
    mwaved = [ pkgs.fftw.dev ];
    ncdf4 = [ pkgs.netcdf ];
    nloptr = [ pkgs.nlopt pkgs.pkg-config ];
    n1qn1 = [ pkgs.gfortran ];
    odbc = [ pkgs.unixODBC ];
    pander = [ pkgs.pandoc pkgs.which ];
    pbdMPI = [ pkgs.mpi ];
    pbdPROF = [ pkgs.mpi ];
    pbdZMQ = lib.optionals stdenv.isDarwin [ pkgs.which ];
    pdftools = [ pkgs.poppler.dev ];
    phytools = [ pkgs.which ];
    PKI = [ pkgs.openssl.dev ];
    png = [ pkgs.libpng.dev ];
    proj4 = [ pkgs.proj ];
    protolite = [ pkgs.protobuf ];
    R2SWF = [ pkgs.zlib pkgs.libpng pkgs.freetype.dev ];
    RAppArmor = [ pkgs.libapparmor ];
    rapportools = [ pkgs.which ];
    rapport = [ pkgs.which ];
    readxl = [ pkgs.libiconv ];
    rcdd = [ pkgs.gmp.dev ];
    RcppCNPy = [ pkgs.zlib.dev ];
    RcppGSL = [ pkgs.gsl_1 ];
    RcppZiggurat = [ pkgs.gsl_1 ];
    reprex = [ pkgs.which ];
    rgdal = [ pkgs.proj.dev pkgs.gdal ];
    rgeos = [ pkgs.geos ];
    Rglpk = [ pkgs.glpk ];
    RGtk2 = [ pkgs.gtk2.dev ];
    rhdf5 = [ pkgs.zlib ];
    Rhdf5lib = [ pkgs.zlib.dev ];
    Rhpc = [ pkgs.zlib pkgs.bzip2.dev pkgs.icu pkgs.xz.dev pkgs.mpi pkgs.pcre.dev ];
    Rhtslib = [ pkgs.zlib.dev pkgs.automake pkgs.autoconf pkgs.bzip2.dev pkgs.xz.dev pkgs.curl.dev ];
    rjags = [ pkgs.jags ];
    rJava = [ pkgs.zlib pkgs.bzip2.dev pkgs.icu pkgs.xz.dev pkgs.pcre.dev pkgs.jdk pkgs.libzip ];
    Rlibeemd = [ pkgs.gsl_1 ];
    rmatio = [ pkgs.zlib.dev ];
    Rmpfr = [ pkgs.gmp pkgs.mpfr.dev ];
    Rmpi = [ pkgs.mpi ];
    RMySQL = [ pkgs.zlib pkgs.libmysqlclient pkgs.openssl.dev ];
    RNetCDF = [ pkgs.netcdf pkgs.udunits ];
    RODBC = [ pkgs.libiodbc ];
    rpanel = [ pkgs.bwidget ];
    Rpoppler = [ pkgs.poppler ];
    RPostgreSQL = [ pkgs.postgresql pkgs.postgresql ];
    RProtoBuf = [ pkgs.protobuf ];
    RSclient = [ pkgs.openssl.dev ];
    Rserve = [ pkgs.openssl ];
    Rssa = [ pkgs.fftw.dev ];
    runjags = [ pkgs.jags ];
    RVowpalWabbit = [ pkgs.zlib.dev pkgs.boost ];
    rzmq = [ pkgs.zeromq pkgs.pkg-config ];
    clustermq = [ pkgs.zeromq ];
    SAVE = [ pkgs.zlib pkgs.bzip2 pkgs.icu pkgs.xz pkgs.pcre ];
    sdcTable = [ pkgs.gmp pkgs.glpk ];
    seewave = [ pkgs.fftw.dev pkgs.libsndfile.dev ];
    seqinr = [ pkgs.zlib.dev ];
    seqminer = [ pkgs.zlib.dev pkgs.bzip2 ];
    sf = [ pkgs.gdal pkgs.proj pkgs.geos ];
    showtext = [ pkgs.zlib pkgs.libpng pkgs.icu pkgs.freetype.dev ];
    simplexreg = [ pkgs.gsl_1 ];
    spate = [ pkgs.fftw.dev ];
    ssanv = [ pkgs.proj ];
    stsm = [ pkgs.gsl_1 ];
    stringi = [ pkgs.icu.dev ];
    survSNP = [ pkgs.gsl_1 ];
    svglite = [ pkgs.libpng.dev ];
    sysfonts = [ pkgs.zlib pkgs.libpng pkgs.freetype.dev ];
    systemfonts = [ pkgs.fontconfig.dev pkgs.freetype.dev ];
    TAQMNGR = [ pkgs.zlib.dev ];
    tesseract = [ pkgs.tesseract pkgs.leptonica ];
    tiff = [ pkgs.libtiff.dev ];
    tkrplot = [ pkgs.xorg.libX11 pkgs.tk.dev ];
    topicmodels = [ pkgs.gsl_1 ];
    udunits2 = [ pkgs.udunits pkgs.expat ];
    units = [ pkgs.udunits ];
    V8 = [ pkgs.v8 ];
    XBRL = [ pkgs.zlib pkgs.libxml2.dev ];
    xml2 = [ pkgs.libxml2.dev ] ++ lib.optionals stdenv.isDarwin [ pkgs.perl ];
    XML = [ pkgs.libtool pkgs.libxml2.dev pkgs.xmlsec pkgs.libxslt ];
    affyPLM = [ pkgs.zlib.dev ];
    bamsignals = [ pkgs.zlib.dev ];
    BitSeq = [ pkgs.zlib.dev ];
    DiffBind = [ pkgs.zlib ];
    ShortRead = [ pkgs.zlib.dev ];
    oligo = [ pkgs.zlib.dev ];
    gmapR = [ pkgs.zlib.dev ];
    Rsubread = [ pkgs.zlib.dev ];
    XVector = [ pkgs.zlib.dev ];
    Rsamtools = [ pkgs.zlib.dev pkgs.curl.dev ];
    rtracklayer = [ pkgs.zlib.dev ];
    affyio = [ pkgs.zlib.dev ];
    VariantAnnotation = [ pkgs.zlib.dev pkgs.curl.dev ];
    snpStats = [ pkgs.zlib.dev ];
    hdf5r = [ pkgs.hdf5.dev ];
  };

  packagesWithBuildInputs = {
    # sort -t '=' -k 2
    gam = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    RcppArmadillo = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    quantreg = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    rmutil = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    robustbase = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    SparseM = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    hexbin = lib.optionals stdenv.isDarwin [ pkgs.libiconv ];
    svKomodo = [ pkgs.which ];
    nat = [ pkgs.which ];
    nat_templatebrains = [ pkgs.which ];
    pbdZMQ = lib.optionals stdenv.isDarwin [ pkgs.darwin.binutils ];
    clustermq = [  pkgs.pkg-config ];
    RMark = [ pkgs.which ];
    RPushbullet = [ pkgs.which ];
    RcppEigen = [ pkgs.libiconv ];
    RCurl = [ pkgs.curl.dev ];
    R2SWF = [ pkgs.pkg-config ];
    rgl = [ pkgs.libGLU pkgs.libGLU.dev pkgs.libGL pkgs.xlibsWrapper ];
    RGtk2 = [ pkgs.pkg-config ];
    RProtoBuf = [ pkgs.pkg-config ];
    Rpoppler = [ pkgs.pkg-config ];
    XML = [ pkgs.pkg-config ];
    cairoDevice = [ pkgs.pkg-config ];
    chebpol = [ pkgs.pkg-config ];
    fftw = [ pkgs.pkg-config ];
    gdtools = [ pkgs.pkg-config ];
    jqr = [ pkgs.jq.lib ];
    kza = [ pkgs.pkg-config ];
    lwgeom = [ pkgs.pkg-config pkgs.proj.dev pkgs.sqlite.dev ];
    magick = [ pkgs.pkg-config ];
    mwaved = [ pkgs.pkg-config ];
    odbc = [ pkgs.pkg-config ];
    openssl = [ pkgs.pkg-config ];
    pdftools = [ pkgs.pkg-config ];
    sf = [ pkgs.pkg-config pkgs.sqlite.dev pkgs.proj.dev ];
    showtext = [ pkgs.pkg-config ];
    spate = [ pkgs.pkg-config ];
    stringi = [ pkgs.pkg-config ];
    sysfonts = [ pkgs.pkg-config ];
    systemfonts = [ pkgs.pkg-config ];
    tesseract = [ pkgs.pkg-config ];
    Cairo = [ pkgs.pkg-config ];
    CLVTools = [ pkgs.gsl ];
    JMcmprsk = [ pkgs.gsl ];
    mashr = [ pkgs.gsl ];
    hadron = [ pkgs.gsl ];
    AMOUNTAIN = [ pkgs.gsl ];
    Rsymphony = [ pkgs.pkg-config pkgs.doxygen pkgs.graphviz pkgs.subversion ];
    tcltk2 = [ pkgs.tcl pkgs.tk ];
    tikzDevice = [ pkgs.which pkgs.texlive.combined.scheme-medium ];
    gridGraphics = [ pkgs.which ];
    adimpro = [ pkgs.which pkgs.xorg.xdpyinfo ];
    mzR = [ pkgs.netcdf ];
    cluster = [ pkgs.libiconv ];
    KernSmooth = [ pkgs.libiconv ];
    nlme = [ pkgs.libiconv ];
    Matrix = [ pkgs.libiconv ];
    mgcv = [ pkgs.libiconv ];
    minqa = [ pkgs.libiconv ];
    igraph = [ pkgs.libiconv ];
    ape = [ pkgs.libiconv ];
    expm = [ pkgs.libiconv ];
    mnormt = [ pkgs.libiconv ];
    pan = [ pkgs.libiconv ];
    phangorn = [ pkgs.libiconv ];
    quadprog = [ pkgs.libiconv ];
    randomForest = [ pkgs.libiconv ];
    sundialr = [ pkgs.libiconv ];
    ucminf = [ pkgs.libiconv ];
    glmnet = [ pkgs.libiconv ];
    mvtnorm = [ pkgs.libiconv ];
    statmod = [ pkgs.libiconv ];
  };

  packagesRequireingX = [
    "accrual"
    "ade4TkGUI"
    "analogue"
    "analogueExtra"
    "AnalyzeFMRI"
    "AnnotLists"
    "AnthropMMD"
    "aplpack"
    "asbio"
    "BAT"
    "BCA"
    "betapart"
    "BiodiversityR"
    "bio_infer"
    "bipartite"
    "biplotbootGUI"
    "blender"
    "cairoDevice"
    "CCTpack"
    "cncaGUI"
    "cocorresp"
    "CommunityCorrelogram"
    "confidence"
    "constrainedKriging"
    "ConvergenceConcepts"
    "cpa"
    "DALY"
    "dave"
    "Deducer"
    "DeducerPlugInExample"
    "DeducerPlugInScaling"
    "DeducerSpatial"
    "DeducerSurvival"
    "DeducerText"
    "Demerelate"
    "detrendeR"
    "dpa"
    "dynamicGraph"
    "dynBiplotGUI"
    "EasyqpcR"
    "EcoVirtual"
    "exactLoglinTest"
    "fat2Lpoly"
    "fbati"
    "FD"
    "feature"
    "FeedbackTS"
    "FFD"
    "fgui"
    "fisheyeR"
    "forams"
    "forensim"
    "FreeSortR"
    "fscaret"
    "gcmr"
    "geomorph"
    "geoR"
    "georob"
    "GGEBiplotGUI"
    "gnm"
    "GrapheR"
    "GroupSeq"
    "gsubfn"
    "GUniFrac"
    "gWidgets2RGtk2"
    "gWidgets2tcltk"
    "HH"
    "HiveR"
    "ic50"
    "iDynoR"
    "in2extRemes"
    "iplots"
    "isopam"
    "IsotopeR"
    "JGR"
    "KappaGUI"
    "likeLTD"
    "logmult"
    "LS2Wstat"
    "MareyMap"
    "memgene"
    "metacom"
    "Meth27QC"
    "migui"
    "miniGUI"
    "mixsep"
    "MplusAutomation"
    "mpmcorrelogram"
    "mritc"
    "multgee"
    "multibiplotGUI"
    "OligoSpecificitySystem"
    "onemap"
    "OpenRepGrid"
    "paleoMAS"
    "pbatR"
    "PBSadmb"
    "PBSmodelling"
    "PCPS"
    "pez"
    "phylotools"
    "picante"
    "plotSEMM"
    "plsRbeta"
    "plsRglm"
    "PopGenReport"
    "poppr"
    "powerpkg"
    "PredictABEL"
    "prefmod"
    "PrevMap"
    "r4ss"
    "RandomFields"
    "rareNMtests"
    "rAverage"
    "Rcmdr"
    "RcmdrPlugin_coin"
    "RcmdrPlugin_depthTools"
    "RcmdrPlugin_DoE"
    "RcmdrPlugin_EACSPIR"
    "RcmdrPlugin_EBM"
    "RcmdrPlugin_EcoVirtual"
    "RcmdrPlugin_EZR"
    "RcmdrPlugin_FactoMineR"
    "RcmdrPlugin_HH"
    "RcmdrPlugin_IPSUR"
    "RcmdrPlugin_KMggplot2"
    "RcmdrPlugin_lfstat"
    "RcmdrPlugin_MA"
    "RcmdrPlugin_MPAStats"
    "RcmdrPlugin_orloca"
    "RcmdrPlugin_plotByGroup"
    "RcmdrPlugin_pointG"
    "RcmdrPlugin_ROC"
    "RcmdrPlugin_sampling"
    "RcmdrPlugin_SCDA"
    "RcmdrPlugin_SLC"
    "RcmdrPlugin_sos"
    "RcmdrPlugin_steepness"
    "RcmdrPlugin_survival"
    "RcmdrPlugin_TeachingDemos"
    "RcmdrPlugin_temis"
    "RcmdrPlugin_UCA"
    "recluster"
    "relimp"
    "rgl"
    "RHRV"
    "rich"
    "RNCEP"
    "RSDA"
    "RSurvey"
    "simba"
    "Simile"
    "SimpleTable"
    "SOLOMON"
    "soundecology"
    "spatsurv"
    "sqldf"
    "SSDforR"
    "statcheck"
    "StatDA"
    "STEPCAM"
    "stosim"
    "strvalidator"
    "stylo"
    "svDialogstcltk"
    "svIDE"
    "svSocket"
    "svWidgets"
    "SYNCSA"
    "SyNet"
    "tcltk2"
    "TestScorer"
    "TIMP"
    "tkrplot"
    "tmap"
    "tspmeta"
    "TTAinterfaceTrendAnalysis"
    "twiddler"
    "vcdExtra"
    "VecStatGraphs3D"
    "vegan"
    "vegan3d"
    "vegclust"
    "x12GUI"
  ];

  packagesToSkipCheck = [
    "Rmpi"     # tries to run MPI processes
    "pbdMPI"   # tries to run MPI processes
    "data_table" # fails to rename shared library before check
  ];

  # Packages which cannot be installed due to lack of dependencies or other reasons.
  brokenPackages = [
  ];

  otherOverrides = old: new: {
    stringi = old.stringi.overrideDerivation (attrs: {
      postInstall = let
        icuName = "icudt52l";
        icuSrc = pkgs.fetchzip {
          url = "http://static.rexamine.com/packages/${icuName}.zip";
          sha256 = "0hvazpizziq5ibc9017i1bb45yryfl26wzfsv05vk9mc1575r6xj";
          stripRoot = false;
        };
        in ''
          ${attrs.postInstall or ""}
          cp ${icuSrc}/${icuName}.dat $out/library/stringi/libs
        '';
    });

    xml2 = old.xml2.overrideDerivation (attrs: {
      preConfigure = ''
        export LIBXML_INCDIR=${pkgs.libxml2.dev}/include/libxml2
        patchShebangs configure
        '';
    });

    rzmq = old.rzmq.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    clustermq = old.clustermq.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    Cairo = old.Cairo.overrideDerivation (attrs: {
      NIX_LDFLAGS = "-lfontconfig";
    });

    curl = old.curl.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    RcppParallel = old.RcppParallel.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    ggbio = old.ggbio.overrideDerivation (attrs: {
      patches = [
        (pkgs.fetchpatch {
          url = "https://github.com/tengfei/ggbio/commit/b04a9840cf5c0bd0514db2536f2e610bbd364727.patch";
          sha256 = "blwtObyIYo1UBWz4nlmcJ8Nyw/n0qwmJrtwFWuoUyMg=";
        })
      ];
    });

    RcppArmadillo = old.RcppArmadillo.overrideDerivation (attrs: {
      patchPhase = "patchShebangs configure";
    });

    data_table = old.data_table.overrideDerivation (attrs: {
      NIX_CFLAGS_COMPILE = attrs.NIX_CFLAGS_COMPILE + " -fopenmp";
      patchPhase = "patchShebangs configure";
    });

    ModelMetrics = old.ModelMetrics.overrideDerivation (attrs: {
      NIX_CFLAGS_COMPILE = attrs.NIX_CFLAGS_COMPILE
        + lib.optionalString stdenv.isDarwin " -fopenmp";
    });

    rpf = old.rpf.overrideDerivation (attrs: {
      patchPhase = "patchShebangs configure";
    });

    BayesXsrc = old.BayesXsrc.overrideDerivation (attrs: {
      patches = [ ./patches/BayesXsrc.patch ];
    });

    Rhdf5lib = old.Rhdf5lib.overrideDerivation (attrs: {
      patches = [ ./patches/Rhdf5lib.patch ];
    });

    rJava = old.rJava.overrideDerivation (attrs: {
      preConfigure = ''
        export JAVA_CPPFLAGS=-I${pkgs.jdk}/include/
        export JAVA_HOME=${pkgs.jdk}
      '';
    });

    JavaGD = old.JavaGD.overrideDerivation (attrs: {
      preConfigure = ''
        export JAVA_CPPFLAGS=-I${pkgs.jdk}/include/
        export JAVA_HOME=${pkgs.jdk}
      '';
    });

    jqr = old.jqr.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    pbdZMQ = old.pbdZMQ.overrideDerivation (attrs: {
      postPatch = lib.optionalString stdenv.isDarwin ''
        for file in R/*.{r,r.in}; do
            sed -i 's#system("which \(\w\+\)"[^)]*)#"${pkgs.darwin.cctools}/bin/\1"#g' $file
        done
      '';
    });

    Rmpi = old.Rmpi.overrideDerivation (attrs: {
      configureFlags = [
        "--with-Rmpi-type=OPENMPI"
      ];
    });

    Rmpfr = old.Rmpfr.overrideDerivation (attrs: {
      configureFlags = [
        "--with-mpfr-include=${pkgs.mpfr.dev}/include"
      ];
    });

    RVowpalWabbit = old.RVowpalWabbit.overrideDerivation (attrs: {
      configureFlags = [
        "--with-boost=${pkgs.boost.dev}" "--with-boost-libdir=${pkgs.boost.out}/lib"
      ];
    });

    RAppArmor = old.RAppArmor.overrideDerivation (attrs: {
      patches = [ ./patches/RAppArmor.patch ];
      LIBAPPARMOR_HOME = pkgs.libapparmor;
    });

    RMySQL = old.RMySQL.overrideDerivation (attrs: {
      MYSQL_DIR="${pkgs.libmysqlclient}";
      preConfigure = ''
        patchShebangs configure
      '';
    });

    devEMF = old.devEMF.overrideDerivation (attrs: {
      NIX_CFLAGS_LINK = "-L${pkgs.xorg.libXft.out}/lib -lXft";
      NIX_LDFLAGS = "-lX11";
    });

    slfm = old.slfm.overrideDerivation (attrs: {
      PKG_LIBS = "-L${pkgs.blas}/lib -lblas -L${pkgs.lapack}/lib -llapack";
    });

    SamplerCompare = old.SamplerCompare.overrideDerivation (attrs: {
      PKG_LIBS = "-L${pkgs.blas}/lib -lblas -L${pkgs.lapack}/lib -llapack";
    });

    EMCluster = old.EMCluster.overrideDerivation (attrs: {
      patches = [ ./patches/EMCluster.patch ];
    });

    spMC = old.spMC.overrideDerivation (attrs: {
      patches = [ ./patches/spMC.patch ];
    });

    openssl = old.openssl.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
      '';
      PKGCONFIG_CFLAGS = "-I${pkgs.openssl.dev}/include";
      PKGCONFIG_LIBS = "-Wl,-rpath,${pkgs.openssl.out}/lib -L${pkgs.openssl.out}/lib -lssl -lcrypto";
    });

    websocket = old.websocket.overrideDerivation (attrs: {
      PKGCONFIG_CFLAGS = "-I${pkgs.openssl.dev}/include";
      PKGCONFIG_LIBS = "-Wl,-rpath,${pkgs.openssl.out}/lib -L${pkgs.openssl.out}/lib -lssl -lcrypto";
    });

    Rserve = old.Rserve.overrideDerivation (attrs: {
      patches = [ ./patches/Rserve.patch ];
      configureFlags = [
        "--with-server" "--with-client"
      ];
    });

    nloptr = old.nloptr.overrideDerivation (attrs: {
      # Drop bundled nlopt source code. Probably unnecessary, but I want to be
      # sure we're using the system library, not this one.
      preConfigure = "rm -r src/nlopt_src";
    });

    V8 = old.V8.overrideDerivation (attrs: {
      postPatch = ''
        substituteInPlace configure \
          --replace " -lv8_libplatform" ""
      '';

      preConfigure = ''
        export INCLUDE_DIR=${pkgs.v8}/include
        export LIB_DIR=${pkgs.v8}/lib
        patchShebangs configure
      '';
    });

    acs = old.acs.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    gdtools = old.gdtools.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
      NIX_LDFLAGS = "-lfontconfig -lfreetype";
    });

    magick = old.magick.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    libgeos = old.libgeos.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    protolite = old.protolite.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    rpanel = old.rpanel.overrideDerivation (attrs: {
      preConfigure = ''
        export TCLLIBPATH="${pkgs.bwidget}/lib/bwidget${pkgs.bwidget.version}"
      '';
      TCLLIBPATH = "${pkgs.bwidget}/lib/bwidget${pkgs.bwidget.version}";
    });

    RPostgres = old.RPostgres.overrideDerivation (attrs: {
      preConfigure = ''
        export INCLUDE_DIR=${pkgs.postgresql}/include
        export LIB_DIR=${pkgs.postgresql.lib}/lib
        patchShebangs configure
        '';
    });

    OpenMx = old.OpenMx.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    odbc = old.odbc.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    x13binary = old.x13binary.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
    });

    geojsonio = old.geojsonio.overrideDerivation (attrs: {
      buildInputs = [ cacert ] ++ attrs.buildInputs;
    });

    rstan = old.rstan.overrideDerivation (attrs: {
      NIX_CFLAGS_COMPILE = "${attrs.NIX_CFLAGS_COMPILE} -DBOOST_PHOENIX_NO_VARIADIC_EXPRESSION";
    });

    mongolite = old.mongolite.overrideDerivation (attrs: {
      preConfigure = ''
        patchShebangs configure
        '';
      PKGCONFIG_CFLAGS = "-I${pkgs.openssl.dev}/include -I${pkgs.cyrus_sasl.dev}/include -I${pkgs.zlib.dev}/include";
      PKGCONFIG_LIBS = "-Wl,-rpath,${pkgs.openssl.out}/lib -L${pkgs.openssl.out}/lib -L${pkgs.cyrus_sasl.out}/lib -L${pkgs.zlib.out}/lib -lssl -lcrypto -lsasl2 -lz";
    });

    ps = old.ps.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    rlang = old.rlang.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    systemfonts = old.systemfonts.overrideDerivation (attrs: {
      preConfigure = "patchShebangs configure";
    });

    littler = old.littler.overrideAttrs (attrs: with pkgs; {
      buildInputs = [ pcre xz zlib bzip2 icu which ] ++ attrs.buildInputs;
      postInstall = ''
        install -d $out/bin $out/share/man/man1
        ln -s ../library/littler/bin/r $out/bin/r
        ln -s ../library/littler/bin/r $out/bin/lr
        ln -s ../../../library/littler/man-page/r.1 $out/share/man/man1
        # these won't run without special provisions, so better remove them
        rm -r $out/library/littler/script-tests
      '';
    });

  };
in
  self
