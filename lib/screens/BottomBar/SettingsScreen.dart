import 'package:downloadsplatform/Models/auth_provider.dart';
import 'package:downloadsplatform/screens/BottomBar/SecuritySettingsScreen.dart';
import 'package:downloadsplatform/screens/BottomBar/StoreScreen.dart';
import 'package:downloadsplatform/screens/LoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {




  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    // Dynamic list based on authentication status
    final List<Map<String, dynamic>> settingsItems = [
      // {'name': 'المتجر', 'icon': Icons.store},
      {'name': 'إعدادات الحماية', 'icon': Icons.lock},
    ];

    if (userProvider.isAuthenticated) {
      // settingsItems.addAll([
      //   // {'name': 'الملف الشخصي', 'icon': Icons.person},
      //   // {'name': 'تسجيل الخروج', 'icon': Icons.exit_to_app},
      // ]);
    } else {
      // settingsItems.add(
      //   {'name': 'تسجيل الدخول', 'icon': Icons.login_outlined},
      // );
    }

    return Scaffold(
      appBar: null,
      body: ListView.builder(
        itemCount: settingsItems.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(settingsItems[index]['icon']), // Icon on the left
            title: Text(settingsItems[index]['name']), // Item name
            trailing: Icon(Icons.chevron_right), // Chevron on the right
            onTap: () {
              if (settingsItems[index]['name'] == 'الملف الشخصي' && userProvider.isAuthenticated) {
                // Navigate to the ProfileScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Directionality(textDirection:TextDirection.rtl,child: ProfileScreen()),
                  ),
                );
              }else if (settingsItems[index]['name'] == 'تسجيل الخروج' && userProvider.isAuthenticated) {
                // Navigate to the ProfileScreen
                // Call the signOut method
                userProvider.signOut();
                // Optionally, navigate to the login screen or home screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(), // Replace with your login screen
                  ),
                );

              }else if (settingsItems[index]['name'] == 'تسجيل الدخول' && !userProvider.isAuthenticated) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(), // Replace with your login screen
                  ),
                );

              }
              else if (settingsItems[index]['name'] == 'المتجر') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoreScreen(),
                  ),
                );
              }else if (settingsItems[index]['name'] == 'إعدادات الحماية') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SecuritySettings()),
                );
              }

              else {
                // Navigate to other screens (if needed)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailScreen(item: settingsItems[index]['name']),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}




class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _selectedGender;
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _lastNameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _birthDateController = TextEditingController();
  TextEditingController _countryController = TextEditingController();

  bool _isLoading = false;
  List<String> countries = []; // List to store country names
  String? _selectedCountry; // Selected country from the dropdown

  @override
  void initState() {
    super.initState();
    _loadCountries(); // Load countries from JSON file
    _fetchCurrentUser(); // Fetch user data
  }

  // Load countries from the JSON file
  Future<void> _loadCountries() async {
    try {
      String data = await rootBundle.loadString('assets/countries.json');
      final List<dynamic> jsonData = json.decode(data);
      setState(() {
        countries = jsonData.map((country) => country['label'].toString()).toList();
      });
    } catch (e) {
      print('Error loading countries: $e');
    }
  }

  // Fetch user data from the API
  Future<void> _fetchCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.get(
        Uri.parse('https://downloadsplatform.com/api/auth/check-auth'),
        headers: {'Content-Type': 'application/json', 'Cookie': 'auth_token=$token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> userData = responseData['user'];
        // Update the user data in UserProvider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.signIn(userData); // Update the user data in the provider

        setState(() {
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _birthDateController.text = userData['birthDate'] ?? '';
          _selectedCountry = userData['country'] ?? ''; // Set initial country value
          _countryController.text = _selectedCountry ?? ''; // Set controller text
          _selectedGender = userData['gender'] ?? 'ذكر';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch user data')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update user profile
  Future<void> _updateProfile() async {


    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> updatedUserData = {
        'firstName': _firstNameController.text ?? "",
        'lastName': _lastNameController.text ?? "",
        'email': _emailController.text ?? "",
        'phone': _phoneController.text ?? "",
        'birthDate': _birthDateController.text ?? "",
        'country': _selectedCountry ?? "", // Use the selected country
        'gender': _selectedGender ?? "",
      };
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      final response = await http.post(
        Uri.parse('https://downloadsplatform.com/api/auth/updateUserDetails'),
        headers: {'Content-Type': 'application/json','Cookie': 'auth_token=$token'},
        body: json.encode(updatedUserData),
      );


      if (response.statusCode == 200) {

        final Map<String, dynamic> userData = updatedUserData;
        // Update the user data in UserProvider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.signIn(userData); // Update the user data in the provider
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح')),
        );

        // Optionally, refresh the user data
        _fetchCurrentUser();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الملف الشخصي'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage:
                      AssetImage('assets/images/profile.png'), // Add a profile image
                    ),
                    SizedBox(height: 10),
                    Text(
                      _emailController.text,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Form Fields
              Text('الاسم الأول', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل الاسم الأول',
                ),
              ),
              SizedBox(height: 20),

              Text('الاسم الأخير', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل الاسم الأخير',
                ),
              ),
              SizedBox(height: 20),

              Text('البريد الإلكتروني', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل البريد الإلكتروني',
                ),
              ),
              SizedBox(height: 20),



              Text('تاريخ الميلاد', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              TextField(
                controller: _birthDateController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'أدخل تاريخ الميلاد',
                ),
                readOnly: true, // Make the field read-only
                onTap: () async {
                  // Show the date picker dialog
                  DateTime? selectedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(), // Default initial date
                    firstDate: DateTime(1900), // Earliest selectable date
                    lastDate: DateTime.now(), // Latest selectable date (today)
                    builder: (BuildContext context, Widget? child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.blue, // Header background color
                            onPrimary: Colors.white, // Header text color
                          ),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl, // Set RTL for the date picker
                          child: child!,
                        ),
                      );
                    },
                  );

                  // Update the TextField with the selected date
                  if (selectedDate != null) {
                    setState(() {
                      _birthDateController.text =
                      "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";
                    });
                  }
                },
              ),
              SizedBox(height: 20),

              // Country Dropdown with Search
              Text('البلد', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              TypeAheadField<String>(
                controller: _countryController, // Add controller here
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'ابحث عن بلد',
                    ),
                  );
                },
                suggestionsCallback: (pattern) async {
                  return countries.where((country) =>
                      country.toLowerCase().contains(pattern.toLowerCase())).toList();
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    title: Text(suggestion),
                  );
                },
                onSelected: (suggestion) {
                  setState(() {
                    _selectedCountry = suggestion;
                    _countryController.text = suggestion;
                  });
                },
                emptyBuilder: (context) { // Use emptyBuilder instead of noItemsFoundBuilder
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('لا توجد نتائج'),
                  );
                },
              ),
              SizedBox(height: 20),

              // Gender Selection
              Text('الجنس', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Row(
                children: [
                  Radio<String>(
                    value: 'ذكر',
                    groupValue: _selectedGender,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  Text('ذكر'),
                  Radio<String>(
                    value: 'أنثى',
                    groupValue: _selectedGender,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  Text('أنثى'),
                ],
              ),
              SizedBox(height: 20),

              // Confirm Button
              Center(
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  child: Text('تأكيد', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class DetailScreen extends StatelessWidget {
  final String item;

  DetailScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item),
      ),
      body: Center(
        child: Text('Details for $item'),
      ),
    );
  }
}