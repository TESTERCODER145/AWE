import 'package:downloadsplatform/Models/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:intl/intl.dart' as intl; // Rename the import to avoid conflict
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class CompleteProfileScreen extends StatefulWidget {
  @override
  _CompleteProfileScreenState createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  // final _nameController = TextEditingController();
  // Replace the _nameController with these:
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedGender;
  Country? _selectedCountry;
  DateTime? _selectedDate;
  List<Country> _countries = [];

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final String jsonString =
        await rootBundle.loadString('assets/countries.json');
    final List<dynamic> jsonData = jsonDecode(jsonString);
    setState(() {
      _countries = jsonData.map((country) {
        return Country(
          isoCode: country['value'],
          iso3Code: country['value'],
          phoneCode: country['dialvalue'],
          name: country['label'],
        );
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        print(_selectedDate); // Debugging: Check if the date is updated
      });
    }
  }

  Future<void> _submitForm(BuildContext context, String email) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء اختيار الجنس')),
        );
        return;
      }
      if (_selectedCountry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء اختيار الدولة')),
        );
        return;
      }
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء اختيار تاريخ الميلاد')),
        );
        return;
      }

      final Map<String, dynamic> data = {
        'email': email,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'gender': _selectedGender,
        'country': _selectedCountry?.name,
        'birthday': _selectedDate?.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('https://downloadsplatform.com/api/auth/update-user-details'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        // Update local user data
        userProvider.updateUserData({
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'gender': _selectedGender,
          'country': _selectedCountry?.name,
          'birthday': _selectedDate?.toIso8601String(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح!')),
        );
        Navigator.of(context).pushReplacementNamed('/welcome');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('فشل تحديث الملف الشخصي. الرجاء المحاولة مرة أخرى.')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final email = ModalRoute.of(context)!.settings.arguments as String;
    return Scaffold(
      appBar: AppBar(
        title: Text('اكمال الحساب'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  'قم بالكامل الحساب',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                // Replace the Name Input section with these two fields:

                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'الاسم الأول',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال الاسم الأول';
                      }
                      return null;
                    },
                  ),
                ),

// Last Name Input
                SizedBox(height: 20),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'الاسم الأخير',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال الاسم الأخير';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 10),
                // Gender Selection (RTL)
                Directionality(
                  textDirection:
                      TextDirection.rtl, // Use Flutter's TextDirection enum
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الجنس'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedGender = 'ذكر';
                              });
                            },
                            child: Text('ذكر'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedGender == 'ذكر' ? Colors.blue : null,
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedGender = 'أنثى';
                              });
                            },
                            child: Text('أنثى'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedGender == 'أنثى' ? Colors.blue : null,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedGender == null)
                        Text(
                          'الرجاء اختيار الجنس',
                          style: TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                // Country Dropdown with Search (RTL)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: DropdownSearch<Country>(
                    compareFn: (Country item1, Country item2) => item1.isoCode == item2.isoCode,
                    items: (String filter, LoadProps? loadProps) async {
                      // Return the preloaded list of countries
                      return _countries;
                    },
                    itemAsString: (Country country) => country.name,
                    onChanged: (Country? country) {
                      setState(() {
                        _selectedCountry = country;
                      });
                    },
                    selectedItem: _selectedCountry,
                    dropdownBuilder:
                        (BuildContext context, Country? selectedItem) {
                      return Text(
                        selectedItem?.name ?? 'اختر الدولة',
                        style: TextStyle(fontSize: 16),
                      );
                    },
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'ابحث عن الدولة',
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null) {
                        return 'الرجاء اختيار الدولة';
                      }
                      return null;
                    },
                  ),
                ),
                if (_selectedCountry == null)
                  Text(
                    'الرجاء اختيار الدولة',
                    style: TextStyle(color: Colors.red),
                  ),
                SizedBox(height: 10),
                // Date Picker (RTL)
                Directionality(
                  textDirection:
                      TextDirection.rtl, // Use Flutter's TextDirection enum
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate == null
                              ? 'اختر تاريخ الميلاد'
                              : '${intl.DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                if (_selectedDate == null)
                  Text(
                    'الرجاء اختيار تاريخ الميلاد',
                    style: TextStyle(color: Colors.red),
                  ),
                SizedBox(height: 20),
                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _submitForm(context, email),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'تأكيد',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
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
