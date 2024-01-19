// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:geolocator/geolocator.dart';
import 'package:one_clock/one_clock.dart';
import 'package:intl/intl.dart';
import 'package:weather/weather.dart';

import 'model.dart';

/// Returns a clock [Widget] with [ClockModel].
///
/// Example:
///   final myClockBuilder = (ClockModel model) => AnalogClock(model);
///
/// Contestants: Do not edit this.
typedef Widget ClockBuilder(ClockModel model);

/// Wrapper for clock widget to allow for customizations.
///
/// Puts the clock in landscape orientation with an aspect ratio of 5:3.
/// Provides a drawer where users can customize the data that is sent to the
/// clock. To show/hide the drawer, double-tap the clock.
///
/// To use the [ClockCustomizer], pass your clock into it, using a ClockBuilder.
///
/// ```
///   final myClockBuilder = (ClockModel model) => AnalogClock(model);
///   return ClockCustomizer(myClockBuilder);
/// ```
/// Contestants: Do not edit this.
class ClockCustomizer extends StatefulWidget {
  const ClockCustomizer(this._clock);

  /// The clock widget with [ClockModel], to update and display.
  final ClockBuilder _clock;

  @override
  _ClockCustomizerState createState() => _ClockCustomizerState();
}

class _ClockCustomizerState extends State<ClockCustomizer> {
  final _model = ClockModel();
  ThemeMode? _themeMode = ThemeMode.light;
  bool _configButtonShown = false;
  late Weather weatherInfo;
  bool _weatherInfoAvailable = false;
  String weatherIcon = '';
  String address = '';

  @override
  void initState() {
    super.initState();
    _model.addListener(_handleModelChange);
    _getCurrentWeather().then((weather) {
      setState(() {
        _weatherInfoAvailable = true;
        weatherInfo = weather;
        weatherIcon = weather.weatherIcon!;
        address = weather.areaName! + ', ' + weather.country!;
      });
    });
  }

  @override
  void dispose() {
    _model.removeListener(_handleModelChange);
    _model.dispose();
    super.dispose();
  }

  void _handleModelChange() => setState(() {});

  Widget _enumMenu<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          onChanged: onChanged,
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(enumToString(item)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _textField(String currentValue, String label, ValueChanged<String> onChanged) {
    return TextField(
      decoration: InputDecoration(
        hintText: currentValue,
        helperText: label,
      ),
      onChanged: onChanged,
    );
  }

  Widget _configDrawer(BuildContext context) {
    return SafeArea(
      child: Drawer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                // _textField(_model.location, 'Location', (String location) {
                //   setState(() {
                //     _model.location = location;
                //   });
                // }),
                // _textField(_model.temperature.toString(), 'Temperature', (String temperature) {
                //   setState(() {
                //     _model.temperature = double.parse(temperature);
                //   });
                // }),
                // _enumMenu<ThemeMode?>('Theme', _themeMode, ThemeMode.values.toList()..remove(ThemeMode.system),
                //     (ThemeMode? mode) {
                //   setState(() {
                //     _themeMode = mode;
                //   });
                // }),
                // _switch('24-hour format', _model.is24HourFormat, (bool value) {
                //   setState(() {
                //     debugPrint('FullScreenWindow.setFullScreen(true)');
                //     FullScreenWindow.setFullScreen(true);
                //     _model.is24HourFormat = value;
                //   });
                // }),
                _switch('Show weather', _model.showWeather, (bool value) {
                  setState(() {
                    debugPrint('Show weather');
                    _model.showWeather = value;
                  });
                }),
                _switch('Show time', _model.showTime, (bool value) {
                  setState(() {
                    debugPrint('Show time');
                    _model.showTime = value;
                  });
                }),
                // _enumMenu<WeatherCondition?>('Weather', _model.weatherCondition, WeatherCondition.values,
                //     (WeatherCondition? condition) {
                //   setState(() {
                //     _model.weatherCondition = condition;
                //   });
                // }),
                // _enumMenu<TemperatureUnit?>('Units', _model.unit, TemperatureUnit.values, (TemperatureUnit? unit) {
                //   setState(() {
                //     _model.unit = unit;
                //   });
                // }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _configButton() {
    return Builder(
      builder: (BuildContext context) {
        return SafeArea(
            child: IconButton(
          icon: Icon(Icons.settings),
          tooltip: 'Configure clock',
          onPressed: () {
            Scaffold.of(context).openEndDrawer();
            setState(() {
              _configButtonShown = false;
            });
          },
        ));
      },
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  Future<Weather> _getCurrentWeather() async {
    Position position = await _determinePosition();
    WeatherFactory weatherFactory = new WeatherFactory("");
    return await weatherFactory.currentWeatherByLocation(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final clock = Center(
      child: widget._clock(_model),
    );
    final height = MediaQuery.of(context).size.height;
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        endDrawer: _configDrawer(context),
        body: Container(
          height: height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _configButtonShown = !_configButtonShown;
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                clock,
                _model.showTime
                    ? SafeArea(
                        child: Align(
                            alignment: MediaQuery.of(context).orientation == Orientation.landscape
                                ? Alignment.centerRight
                                : Alignment.topCenter,
                            child: DigitalClock(
                                padding: MediaQuery.of(context).orientation == Orientation.landscape
                                    ? EdgeInsets.fromLTRB(30, 0, 30, 0)
                                    : EdgeInsets.fromLTRB(0, 30, 0, 30),
                                showSeconds: true,
                                isLive: true,
                                textScaleFactor: 1.5,
                                digitalClockTextColor: Colors.white,
                                datetime: DateTime.now())))
                    : Container(),
                _model.showWeather
                    ? SafeArea(
                        child: Align(
                        alignment: MediaQuery.of(context).orientation == Orientation.landscape
                            ? Alignment.centerLeft
                            : Alignment.bottomCenter,
                        child: !_weatherInfoAvailable
                            ? Container()
                            : Container(
                                padding: MediaQuery.of(context).orientation == Orientation.landscape
                                    ? EdgeInsets.fromLTRB(30, 0, 30, 0)
                                    : EdgeInsets.fromLTRB(0, 30, 0, 30),
                                child: Column(
                                  mainAxisAlignment: MediaQuery.of(context).orientation == Orientation.landscape
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MediaQuery.of(context).orientation == Orientation.landscape
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        CachedNetworkImage(
                                            imageUrl: "http://openweathermap.org/img/w/" + weatherIcon + ".png"),
                                        Text(weatherInfo.temperature!.celsius!.toInt().toString() + '°C',
                                            style: textTheme.displaySmall),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MediaQuery.of(context).orientation == Orientation.landscape
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        Text(
                                            'L:' +
                                                weatherInfo.tempMin!.celsius!.toInt().toString() +
                                                '°C H:' +
                                                weatherInfo.tempMax!.celsius!.toInt().toString() +
                                                '°C',
                                            style: textTheme.bodyMedium),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MediaQuery.of(context).orientation == Orientation.landscape
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        Text(address, style: textTheme.bodyLarge),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ))
                    : Container(),
                if (_configButtonShown)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 0.7,
                      child: _configButton(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
