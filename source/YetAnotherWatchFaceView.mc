using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Activity as Activity;

// Main WatchFaace view
// ToDo:: 
//        -- 1. Create Wrapper around ObjectStore 
//        2. Move UI logic to functions
//        -- 3. Fix Timezone Issue 
//		  -- 4. Add option to show city name
//		  -- 5. Adjust exchange rate output
//        6. Refactor backround process (error handling)
//        -- 7. Option to Show weather
//        8. Refactor resources, name conventions, etc..
//
class YetAnotherWatchFaceView extends Ui.WatchFace 
{
	hidden var _layout;
	hidden var _conditionIcons;
	hidden var _isShowCurrency;
	hidden var _heartRate = 0;
	
    function initialize() 
    {
        WatchFace.initialize();
        Setting.SetLocationApiKey(Ui.loadResource(Rez.Strings.LocationApiKeyValue));
		Setting.SetAppVersion(Ui.loadResource(Rez.Strings.AppVersionValue));
		Setting.SetIsTest(Ui.loadResource(Rez.Strings.IsTest).toNumber() == 1 ? true : false);
    }

    // Load your resources here
    //
    function onLayout(dc) 
    {
        _layout = Rez.Layouts.MiddleDateLayout(dc);
		setLayout(_layout);
		_conditionIcons = Ui.loadResource(Rez.JsonData.conditionIcons);

		UpdateSetting();
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    //
    function onShow() 
    {
		SetColors();
	}
	
	// Set colors according to property name and app setting
	// 
    function SetColors()
    {
    	for(var i = 0; i < _layout.size(); i++)
    	{
    		if(_layout[i].identifier.find("_time") != null)
    		{
    			_layout[i].setColor(Setting.GetTimeColor());
    		}
    		if(_layout[i].identifier.find("_setbg") != null)
    		{
    			_layout[i].setBackgroundColor(Setting.GetBackgroundColor());
    		}
    		if(_layout[i].identifier.find("_bright") != null)
    		{
    			_layout[i].setColor(Setting.GetBrightColor());
    		}
    		if(_layout[i].identifier.find("_dim") != null)
    		{
    			_layout[i].setColor(Setting.GetDimColor());
    		}
    	}
    	
    	View.findDrawableById("divider")
    		.setLineColor(Setting.GetTimeColor());
    }
    
  	// Implement updated setting from mobile app
  	//
    function UpdateSetting()
    {
    	// Find timezone DST data and save it in object store
    	//
		var tzData = Ui.loadResource(Rez.JsonData.tzData);
        for (var i=0; i < tzData.size(); i++ )
        {
        	if (tzData[i]["Id"] == Setting.GetEtzId())
        	{
        		Setting.SetExtraTimeZone(tzData[i]);
        		break;
        	}
        }
		tzData = null;
		
		// load actual currency symbols and save it in object store
		//
		var symbols = Ui.loadResource(Rez.JsonData.currencySymbols);
		
		// need to erase current exchange rate, since it not actual anymore
		//
		if (!symbols["symbols"][Setting.GetBaseCurrencyId()].equals(Setting.GetBaseCurrency()) ||
			!symbols["symbols"][Setting.GetTargetCurrencyId()].equals(Setting.GetTargetCurrency()))
		{
			var weatherInfo = Setting.GetWeatherInfo();
        	if (weatherInfo != null)
        	{
        		weatherInfo["ExchangeRate"] = 0;
        		Setting.SetWeatherInfo(weatherInfo);
        	}			
		}
		
		// save new symbols in OS
		//
		Setting.SetBaseCurrency(symbols["symbols"][Setting.GetBaseCurrencyId()]);
		Setting.SetTargetCurrency(symbols["symbols"][Setting.GetTargetCurrencyId()]);
		symbols = null;

		_isShowCurrency = Setting.GetIsShowCurrency();
		
		SetColors();
    }
    
    // Return time and abbreviation of extra time-zone
    //
    function GetTzTime(timeNow)
    {
        var localTime = Sys.getClockTime();
        var utcTime = timeNow.add(
        	new Time.Duration( - localTime.timeZoneOffset + localTime.dst));
        
        // by dfault return UTC time
        //
       	var newTz = Setting.GetExtraTimeZone();
		if (newTz == null)
		{
			return [Gregorian.info(utcTime, Time.FORMAT_MEDIUM), "UTC"];
		}
 
 		// find right time interval
 		//
        var index = 0;
        for (var i = 0; i < newTz["Untils"].size(); i++)
        {
        	if (newTz["Untils"][i] != null && newTz["Untils"][i] > utcTime.value())
        	{
        		index = i;
        		break;
        	}
        }
        
        var extraTime = utcTime.add(new Time.Duration(newTz["Offsets"][index] * -60));        
      
        return [Gregorian.info(extraTime, Time.FORMAT_MEDIUM), newTz["Abbrs"][index]];
    }
    
    // calls every second for partial update
    //
    function onPartialUpdate(dc)
    {
    
    	if (Setting.GetIsShowSeconds())
    	{
	    	var clockTime = Sys.getClockTime();
	    	
	    	var secondLabel = View.findDrawableById("Second_time_setbg");
	     	dc.setClip(secondLabel.locX - secondLabel.width, secondLabel.locY, secondLabel.width + 1, secondLabel.height);
	     	secondLabel.setText(clockTime.sec.format("%02d"));
			secondLabel.draw(dc);
		}
		
		if (!_isShowCurrency)
		{
			var chr = Activity.getActivityInfo().currentHeartRate;
			if (chr != null && _heartRate != chr)
			{
				_heartRate = chr;
				var viewPulse = View.findDrawableById("Pulse_bright_setbg");
				dc.setClip(viewPulse.locX, viewPulse.locY, viewPulse.locX + 30, viewPulse.height);
				viewPulse.setText((chr < 100) ? chr.toString() + "  " : chr.toString());
				viewPulse.draw(dc);
				Sys.println("update");
			}
		}

        dc.clearClip();
    }
    
    // Update the view
    //
    function onUpdate(dc) 
    {
    	var activityLocation = Activity.getActivityInfo().currentLocation;
    	if (activityLocation != null)
    	{
    		Setting.SetLastKnownLocation(activityLocation.toDegrees());
    	}
    	
    	var is24Hour = Sys.getDeviceSettings().is24Hour;
		var timeNow = Time.now();
        var gregorianTimeNow = Gregorian.info(timeNow, Time.FORMAT_MEDIUM);
    	
        // Update Time
        //
        View.findDrawableById("Hour_time")
        	.setText(is24Hour 
        		? gregorianTimeNow.hour.format("%02d") 
        		: (gregorianTimeNow.hour % 12 == 0 ? 12 : gregorianTimeNow.hour % 12).format("%02d"));
        	
        View.findDrawableById("DaySign_time_setbg")
        	.setText(is24Hour ? "" : gregorianTimeNow.hour > 11 ? "pm" : "am");
        
        View.findDrawableById("Minute_time")
        	.setText(gregorianTimeNow.min.format("%02d"));
        
       	View.findDrawableById("Second_time_setbg")
        		.setText(Setting.GetIsShowSeconds() ? gregorianTimeNow.sec.format("%02d") : "");
         
        // Update date
        //
        View.findDrawableById("WeekDay_bright")
        	.setText(gregorianTimeNow.day_of_week.toLower());
        
        View.findDrawableById("Month_dim")
        	.setText(gregorianTimeNow.month.toLower());
        
        View.findDrawableById("Day_bright")
        	.setText(gregorianTimeNow.day.format("%02d"));
        
        // Update time in diff TZ
        //
		var tzInfo = GetTzTime(timeNow);

        View.findDrawableById("TzTime_bright")
        	.setText(tzInfo[0].hour.format("%02d") + ":" + tzInfo[0].min.format("%02d"));

        View.findDrawableById("TzTimeTitle_dim")
        	.setText(tzInfo[1]);
        
        // get ActivityMonitor info
        //
		var info = ActivityMonitor.getInfo();
		
		var distanceValues = 
			[(info.distance.toFloat()/100000).format("%2.1f"), 
			(info.distance.toFloat()/160934.4).format("%2.1f"), 
			info.steps.format("%02d")];
		var distanceTitles = ["km", "mi", ""];
		
        View.findDrawableById("Dist_bright")
        	.setText(distanceValues[Setting.GetDistSystem()]);
        
        View.findDrawableById("DistTitle_dim")
        	.setText(distanceTitles[Setting.GetDistSystem()]);
        	
        distanceValues = null;
        distanceTitles = null;
        
        // Weather data
        //
        var weatherInfo = null;
        if (Setting.GetWeatherInfo() != null)
        {
        	weatherInfo = WeatherInfo.FromDictionary(Setting.GetWeatherInfo());
        }
        if (weatherInfo == null || weatherInfo.WeatherStatus != 1 || !Setting.GetIsShowWeather()) // no weather
        {
			View.findDrawableById("Temperature_bright")
				.setText(
					!Setting.GetIsShowWeather() ? "" :
						(Setting.GetLastKnownLocation() == null) ? "no GPS" : "GPS ok");
			View.findDrawableById("TemperatureTitle_dim").setText("");
			View.findDrawableById("Perception_bright").setText("");
			View.findDrawableById("PerceptionTitle_dim").setText("");
			View.findDrawableById("Wind_bright").setText("");
			View.findDrawableById("WindTitle_dim").setText("");
			View.findDrawableById("Condition_time").setText("");
        }
        else
        {
			var temperature = (Setting.GetTempSystem() == 1 ? weatherInfo.Temperature : weatherInfo.Temperature * 1.8 + 32)
				.format(weatherInfo.PerceptionProbability > 99 ? "%2d" : "%2.1f");
			var perception = weatherInfo.PerceptionProbability.format("%2d");
	        
			var temperatureLabel = View.findDrawableById("Temperature_bright");
			temperatureLabel.setText(temperature);
			var temperatureTitleLabel = View.findDrawableById("TemperatureTitle_dim");
			temperatureTitleLabel.locX = temperatureLabel.locX + 1 + dc.getTextWidthInPixels(temperature, Gfx.FONT_TINY);
			temperatureTitleLabel.setText(Setting.GetTempSystem() == 1 ? "c" : "f");
			
			View.findDrawableById("Perception_bright").setText(perception);
			View.findDrawableById("PerceptionTitle_dim").setText("%");
			
			var windLabel = View.findDrawableById("Wind_bright");
			var wind = (weatherInfo.WindSpeed * (Setting.GetWindSystem() == 1 ? 1.94384 : 1)).format("%2.1f");
			windLabel.setText(wind);		
			var windTitleLabel = View.findDrawableById("WindTitle_dim");
			windTitleLabel.locX = windLabel.locX + dc.getTextWidthInPixels(wind, Gfx.FONT_TINY) + 1;
			windTitleLabel.setText(Setting.GetWindSystem() == 1 ? "kn" : "m/s");
	
			var icon = _conditionIcons[weatherInfo.Condition];
			if (icon != null)
			{
				View.findDrawableById("Condition_time").setText(icon);
			}
		}
		
        // Show Currency
        //
       	if (_isShowCurrency)
		{
			var currencyValue = (weatherInfo == null || weatherInfo.ExchangeRate == null) 
				? 0 : weatherInfo.ExchangeRate; 
			if (currencyValue == 0)
			{
				View.findDrawableById("Pulse_bright_setbg")
					.setText("loading...");
				View.findDrawableById("PulseTitle_dim").setText("");					
			}		
			else 
			{
				var format = (currencyValue > 1) ? "%2.2f" : "%1.3f";
				format = (currencyValue < 0.01) ? "%.4f" : format;
				format = (currencyValue < 0.001) ? "%.5f" : format;
				format = (currencyValue < 0.0001) ? "%.6f" : format;
					
				var rateString = currencyValue.format(format);	
				var exchangeLabel = View.findDrawableById("Pulse_bright_setbg");
				exchangeLabel.setText(rateString);
				
				var currencyLabel = View.findDrawableById("PulseTitle_dim");
				if (rateString.length() > 5)
				{
					currencyLabel.locX = exchangeLabel.locX + dc.getTextWidthInPixels(rateString, Gfx.FONT_TINY) + 3;
				}
				else
				{
					currencyLabel.locX = View.findDrawableById("DistTitle_dim").locX;
				}
				currencyLabel.setText(Setting.GetTargetCurrency().toLower());
			}
		}
		else
		{
			View.findDrawableById("PulseTitle_dim").setText("bpm");
		}		
		
		// location
		//
		if (weatherInfo != null && weatherInfo.City != null 
			&& weatherInfo.CityStatus == 1 && Setting.GetIsShowCity())
		{
			// short <city, country> length if it's too long.
			// first cut country, if it's still not fit - cut and add dots.
			//
			var city = weatherInfo.City;
			if (city.length() > 23)
			{
				var dindex = city.find(",");
				city = (dindex == 0) 
					? city
					: city.substring(0, dindex);
				city = city.length() > 23 ? city.substring(0, 22) + "..." : city;
			}
			View.findDrawableById("City_dim").setText(city);
		}
		else
		{
			View.findDrawableById("City_dim").setText("");
		}

		// watch status
		//
		var connectionState = Sys.getDeviceSettings().phoneConnected;
		var viewBt = View.findDrawableById("Bluetooth_dim")
			.setText(connectionState ? "a" : "b");
		
		var batteryLevel = (Sys.getSystemStats().battery).toNumber();
		View.findDrawableById("Battery1_dim").setText((batteryLevel % 10).format("%1d"));
		batteryLevel = batteryLevel / 10;
		if (batteryLevel == 10 )
		{
			View.findDrawableById("Battery3_dim").setText("1");
			View.findDrawableById("Battery2_dim").setText("0");
		}
		else
		{
			View.findDrawableById("Battery3_dim").setText("");
			if (batteryLevel > 0)
			{
				View.findDrawableById("Battery2_dim").setText((batteryLevel % 10).format("%1d"));
			}
			else
			{
				View.findDrawableById("Battery2_dim").setText("");
			}
		}

		if (Setting.GetIsTest())
		{
			View.findDrawableById("debug_version").setText(Rez.Strings.AppVersionValue);
		}
		
        // Call the parent onUpdate function to redraw the layout
        //
        View.onUpdate(dc);
    }
}
