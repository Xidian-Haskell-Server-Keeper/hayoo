{-# OPTIONS #-}

-- ------------------------------------------------------------

module Hayoo.URIConfig
    ( hayooStart
    , hayooRefs
    , hayooGetPackage
    , hayooPackageNames

    , hackagePackages
    , hackageStart
    , hackageGetPackage
    , isHaddockURI
    , isRelHaddockURI
    , isExternalURI

    , editLatestPackage

    , packageVersion
    , packageVersion''

    , fileName
    , packageName
    )
where

import           Data.List         (intercalate, nub, sort)

import           Holumbus.Crawler  (URI, getHtmlReferences, match, sed, simpleFollowRef')

import           Text.XML.HXT.Core (IOSArrow, SysConfigList,
                                    (>>>), (>>.), arr, isA, readDocument)

-- ------------------------------------------------------------

hayooStart                      :: [URI]
hayooStart                      = hackageStart

hayooRefs                       :: Bool -> [String] -> URI -> Bool
hayooRefs                       = hackageRefs

hayooGetPackage                 :: String -> String
hayooGetPackage                 = hackageGetPackage

hackageHome                     :: String
hackageHome                     = "http://hackage.haskell.org/packages/"

hackagePackages                 :: String
hackagePackages                 = "http://hackage.haskell.org/package/" -- no "s" at the end !!!

hackageStartPage                :: URI
hackageStartPage                =  hackageHome                          -- hackage2 change

hackageStart                    :: [URI]
hackageStart                    =  [ hackageStartPage ]

hackageRefs                     :: Bool -> [String] -> URI -> Bool
hackageRefs withDoc pkgs        = simpleFollowRef'
                                  ( (hackagePackages ++ packageName')
                                    : ( if withDoc
                                        then [ hackagePackageDocPath' packageName'
                                               ++ modulePath ++ ext "html"
                                             ]
                                        else []
                                      )
                                  )
                                  [ hackagePackageDocPath
                                    ++ alternatives
                                           [ "doc-index.*" ++ ext "html"  -- no index files
                                           , "src/.*"                     -- no hscolored sources
                                           ]                              -- no old package files
                                  , hackagePackages ++ packageName' ++ packageVersion''
                                  ]
    where
    packageName'
        | null pkgs             = packageName
        | otherwise             = alternatives pkgs

hackagePackageDocPath           :: String
hackagePackageDocPath           = hackagePackageDocPath' packageName

hackagePackageDocPath'          :: String -> String
hackagePackageDocPath' pn       = hackagePackages ++ pn ++ opt packageVersion'' ++ "/docs/"

hackageGetPackage               :: String -> String
hackageGetPackage u
    | isHaddockURI u            = getNameOfPackage u
    | otherwise                 = ""
    where
      getNameOfPackage          = sed (const "") (opt packageVersion'' ++ "/docs/.*") . drop (length hackagePackages)


getHackagePackage               :: String -> String
getHackagePackage s
    | match (hackagePackages ++ packageName) s
                                = drop (length hackagePackages) s
    | otherwise                 = ""

isHaddockURI                    :: URI -> Bool
isHaddockURI                    = match (hackagePackageDocPath ++ modulePath ++ ext "html")

isRelHaddockURI                 :: URI -> Bool
isRelHaddockURI                 = match (modulePath ++ ext "html")

isExternalURI                   :: URI -> Bool
isExternalURI                   = match "[A-Za-z][A-Za-z0-9]*://.*"

-- ------------------------------------------------------------

-- common R.E.s

alternatives                    :: [String] -> String
alternatives                    = ("(" ++) . (++ ")") . intercalate "|"

moduleName                      :: String
moduleName                      = "[A-Z][A-Za-z0-9_]*"

modulePath                      :: String
modulePath                      = moduleName ++ "(-" ++ moduleName ++ ")*"

fileName                        :: String
fileName                        = "[^/?]+"

ext                             :: String -> String
ext                             = ("[.]" ++)

opt                             :: String -> String
opt s                           = "(" ++ s ++ ")?"

packageName                     :: String
packageName                     = "[A-Za-z][A-Za-z0-9_]*(-[A-Za-z0-9_]*[A-Za-z][A-Za-z0-9_]*)*"

packageVersion
  , packageVersion''            :: String

packageVersion                  = "[0-9]+([.][0-9]+)*"          -- there are package versions without sub version no
packageVersion''                = "-" ++ packageVersion

-- ------------------------------------------------------------

-- In the package doc URIs the package version "/xyz-1.2.3.4/" is removed ("/xyz/")
-- This is a redirect to the latest version of the package

editLatestPackage               :: String -> String
editLatestPackage               = sed removeVersion hackagePackageDocPath
   where
     removeVersion              = sed (const "/docs/") (packageVersion'' ++ "/docs/")

-- ------------------------------------------------------------

hayooPackageNames               :: SysConfigList -> IOSArrow b String
hayooPackageNames crawlPars     = ( ( readDocument crawlPars hackageStartPage
                                      >>>
                                      getHtmlReferences
                                      >>>
                                      arr getHackagePackage
                                      >>>
                                      isA (not . null)
                                    )
                                  )
                                  >>. (sort >>> nub)

-- ------------------------------------------------------------

