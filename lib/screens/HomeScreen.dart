import 'package:downloadsplatform/Models/auth_provider.dart';
import 'package:downloadsplatform/screens/BottomBar/HistoryDownload.dart';
import 'package:flutter/material.dart';
import 'package:downloadsplatform/screens/BottomBar/DownloadProgressScreen.dart';
import 'package:downloadsplatform/screens/BottomBar/FilesScreen.dart';
import 'package:downloadsplatform/screens/BottomBar/MainContent.dart';
import 'package:downloadsplatform/screens/BottomBar/SettingsScreen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  @override
  void initState() {
    super.initState();

    // Show SnackBar after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "استخدم التطبيق فيما يرضي الله",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                color: Colors.white
            ),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.black26,
          elevation: 0, // This removes the shadow

        ),
      );
    });

  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserProvider>(context);

    List<Widget> getScreens() {
      final baseScreens = <Widget>[
        Directionality(textDirection:TextDirection.rtl,child: MainContent(
          onDownloadComplete: _onItemTapped, // Pass the callback function
        )),

        Directionality(textDirection:TextDirection.rtl,child: HistoryDownload()), // Add HistoryDownload to the list of screens
        Directionality(textDirection:TextDirection.rtl,child: FileManager()),
        SettingsScreen(),
      ];


        baseScreens.add(SettingsScreen());



      return baseScreens;
    }

    List<BottomNavigationBarItem> getNavigationItems() {
      final baseItems = <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'الرئيسة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.flag),
          label: 'التحميلات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder),
          label: 'الملفات',
        ),
      ];


        baseItems.add(
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        );


      return baseItems;
    }

    final screens = getScreens();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions:null,
      ),
      body: Center(
        child: _selectedIndex < screens.length
            ? screens[_selectedIndex]
            : screens[0],
      ),
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          selectedItemColor: Color(0xff304258),
          unselectedItemColor: Color(0xff4c5a5c),
          selectedLabelStyle: TextStyle(color: Color(0xff304258)),
          backgroundColor: Color(0xfff0f2f5),
          items: getNavigationItems(),
        ),
      ),
    );
  }
}