{-# LANGUAGE QuasiQuotes #-}
module Yesod.Form.Jquery
    ( YesodJquery (..)
    , jqueryDayField
    , maybeJqueryDayField
    , jqueryDayTimeField
    , jqueryDayTimeFieldProfile
    , jqueryAutocompleteField
    , maybeJqueryAutocompleteField
    , jqueryDayFieldProfile
    ) where

import Yesod.Handler
import Yesod.Form
import Yesod.Widget
import Data.Time (UTCTime (..), Day, TimeOfDay (..), timeOfDayToTime,
                  timeToTimeOfDay)
import Yesod.Hamlet
import Data.Char (isSpace)

class YesodJquery a where
    -- | The jQuery Javascript file.
    urlJqueryJs :: a -> Either (Route a) String
    urlJqueryJs _ = Right "http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"

    -- | The jQuery UI 1.8.1 Javascript file.
    urlJqueryUiJs :: a -> Either (Route a) String
    urlJqueryUiJs _ = Right "http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.1/jquery-ui.min.js"

    -- | The jQuery UI 1.8.1 CSS file; defaults to cupertino theme.
    urlJqueryUiCss :: a -> Either (Route a) String
    urlJqueryUiCss _ = Right "http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.1/themes/cupertino/jquery-ui.css"

    -- | jQuery UI time picker add-on.
    urlJqueryUiDateTimePicker :: a -> Either (Route a) String
    urlJqueryUiDateTimePicker _ = Right "http://www.projectcodegen.com/jquery.ui.datetimepicker.js.txt"

jqueryDayField :: YesodJquery y => FormFieldSettings -> FormletField sub y Day
jqueryDayField = requiredFieldHelper jqueryDayFieldProfile

maybeJqueryDayField :: YesodJquery y => FormFieldSettings -> FormletField sub y (Maybe Day)
maybeJqueryDayField = optionalFieldHelper jqueryDayFieldProfile

jqueryDayFieldProfile :: YesodJquery y => FieldProfile sub y Day
jqueryDayFieldProfile = FieldProfile
    { fpParse = maybe
                  (Left "Invalid day, must be in YYYY-MM-DD format")
                  Right
              . readMay
    , fpRender = show
    , fpHamlet = \theId name val isReq -> [$hamlet|
%input#$theId$!name=$name$!type=date!:isReq:required!value=$val$
|]
    , fpWidget = \name -> do
        addScript' urlJqueryJs
        addScript' urlJqueryUiJs
        addStylesheet' urlJqueryUiCss
        addJavaScript [$hamlet|
$$(function(){$$("#$name$").datepicker({dateFormat:'yy-mm-dd'})});
|]
    }

ifRight :: Either a b -> (b -> c) -> Either a c
ifRight e f = case e of
            Left l  -> Left l
            Right r -> Right $ f r

showLeadingZero :: (Show a) => a -> String
showLeadingZero time = let t = show time in if length t == 1 then "0" ++ t else t

jqueryDayTimeField :: YesodJquery y => FormFieldSettings -> FormletField sub y UTCTime
jqueryDayTimeField = requiredFieldHelper jqueryDayTimeFieldProfile

-- use A.M/P.M and drop seconds and "UTC" (as opposed to normal UTCTime show)
jqueryDayTimeUTCTime :: UTCTime -> String
jqueryDayTimeUTCTime (UTCTime day utcTime) =
  let timeOfDay = timeToTimeOfDay utcTime
  in (replace '-' '/' (show day)) ++ " " ++ showTimeOfDay timeOfDay
  where
    showTimeOfDay (TimeOfDay hour minute _) =
      let (h, apm) = if hour < 12 then (hour, "AM") else (hour - 12, "PM")
      in (show h) ++ ":" ++ (showLeadingZero minute) ++ " " ++ apm

jqueryDayTimeFieldProfile :: YesodJquery y => FieldProfile sub y UTCTime
jqueryDayTimeFieldProfile = FieldProfile
    { fpParse  = parseUTCTime
    , fpRender = jqueryDayTimeUTCTime
    , fpHamlet = \theId name val isReq -> [$hamlet|
%input#$theId$!name=$name$!type=date!:isReq:required!value=$val$
|]
    , fpWidget = \name -> do
        addScript' urlJqueryJs
        addScript' urlJqueryUiJs
        addScript' urlJqueryUiDateTimePicker
        addStylesheet' urlJqueryUiCss
        addJavaScript [$hamlet|
$$(function(){$$("#$name$").datetimepicker({dateFormat : "yyyy/mm/dd h:MM TT"})});
|]
    }

parseUTCTime :: String -> Either String UTCTime
parseUTCTime s =
    let (dateS, timeS) = break isSpace (dropWhile isSpace s)
        dateE = parseDate dateS
     in case dateE of
            Left l -> Left l
            Right date ->
                ifRight (parseTime timeS)
                    (UTCTime date . timeOfDayToTime)

jqueryAutocompleteField :: YesodJquery y =>
    Route y -> FormFieldSettings -> FormletField sub y String
jqueryAutocompleteField = requiredFieldHelper . jqueryAutocompleteFieldProfile

maybeJqueryAutocompleteField :: YesodJquery y =>
    Route y -> FormFieldSettings -> FormletField sub y (Maybe String)
maybeJqueryAutocompleteField src =
    optionalFieldHelper $ jqueryAutocompleteFieldProfile src

jqueryAutocompleteFieldProfile :: YesodJquery y => Route y -> FieldProfile sub y String
jqueryAutocompleteFieldProfile src = FieldProfile
    { fpParse = Right
    , fpRender = id
    , fpHamlet = \theId name val isReq -> [$hamlet|
%input.autocomplete#$theId$!name=$name$!type=text!:isReq:required!value=$val$
|]
    , fpWidget = \name -> do
        addScript' urlJqueryJs
        addScript' urlJqueryUiJs
        addStylesheet' urlJqueryUiCss
        addJavaScript [$hamlet|
$$(function(){$$("#$name$").autocomplete({source:"@src@",minLength:2})});
|]
    }

addScript' :: (y -> Either (Route y) String) -> GWidget sub y ()
addScript' f = do
    y <- liftHandler getYesod
    addScriptEither $ f y

addStylesheet' :: (y -> Either (Route y) String) -> GWidget sub y ()
addStylesheet' f = do
    y <- liftHandler getYesod
    addStylesheetEither $ f y

readMay :: Read a => String -> Maybe a
readMay s = case reads s of
                (x, _):_ -> Just x
                [] -> Nothing

-- | Replaces all instances of a value in a list by another value.
-- from http://hackage.haskell.org/packages/archive/cgi/3001.1.7.1/doc/html/src/Network-CGI-Protocol.html#replace
replace :: Eq a => a -> a -> [a] -> [a]
replace x y = map (\z -> if z == x then y else z)
