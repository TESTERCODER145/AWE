// auth_provider.dart
import 'dart:convert';

import 'package:downloadsplatform/Models/User.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  User get currentUser => _currentUser ?? User(role: UserRole.guest);
  bool get isAuthenticated => _currentUser != null;
  // Add to UserProvider class
  void updateUserData(Map<String, dynamic> newData) async {
    if (_currentUser != null) {
      // Merge new data with existing user data
      _currentUser = _currentUser!.copyWith(
        userData: {
          ...?_currentUser!.userData,
          ...newData,
          'firstName': newData['firstName'],
          'lastName': newData['lastName'],
          'gender': newData['gender'],
          'country': newData['country'],
          'birthday': newData['birthday'],
        },
      );

      await _saveUserData(_currentUser!.userData??{});
      notifyListeners();
    }
  }


  Future<void> signIn(Map<String, dynamic> userData) async {
    print("***********");
    print(userData);
    _currentUser = User(
      id: userData['id'],
      email: userData['email'],
      role: UserRole.authenticated,
      userData: userData,
    );
    _isInitialized = true;
    await _saveUserData(userData);
    notifyListeners();
  }

  void signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken'); // Clear the token
    _currentUser = null;
    _isInitialized = false;
    await _clearUserData();
    notifyListeners();
  }
  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(userData));
    // Also update current user instance
    _currentUser = User(
      id: userData['id'],
      email: userData['email'],
      role: UserRole.authenticated,
      userData: userData,
    );
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
  }
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      _currentUser = User(
        id: userData['id'],
        email: userData['email'],
        role: UserRole.authenticated,
        userData: userData,
      );
      _isInitialized = true;
      notifyListeners();
    }
  }


  bool canAccessFeature(Feature feature) {
    return currentUser.canAccess(feature);
  }
}



