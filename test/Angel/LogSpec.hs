module Angel.LogSpec (spec) where

import Angel.Log

import Data.Time
import Data.Time.Calendar (fromGregorian)
import Data.Time.LocalTime (timeOfDayToTime,
                            TimeOfDay(..),
                            TimeZone(..),
                            ZonedTime(..))

import SpecHelper


spec :: TestTree
spec = testGroup "Angel.Log"
  [
    testGroup "cleanCalendar"
    [
      testCase "formats the time correctly" $
        cleanCalendar dateTime @?= "2012/09/12 03:14:59"
    ]
  ]
  --where time = CalendarTime 2012 September 12 3 14 59 0 Tuesday 263 "Pacific" -25200 True
  where dateTime  = ZonedTime localTime zone
        localTime = LocalTime day tod
        day       = fromGregorian 2012 9 12
        tod       = TimeOfDay 3 14 59
        zone      = TimeZone (-420) False "PDT"
