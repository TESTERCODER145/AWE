import 'package:downloadsplatform/Models/Service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StoreScreen extends StatefulWidget {
  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Service> services = [];

  @override
  void initState() {
    super.initState();
    fetchServices();
  }

  Future<void> fetchServices() async {
    try {
      final response = await http.get(Uri.parse('https://downloadsplatform.com/api/services'));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);

        if (data.containsKey('services') && data['services'] is List) {
          setState(() {
            services = (data['services'] as List).map((json) => Service.fromJson(json)).toList();
          });
        } else {
          throw Exception('Invalid API response format: Expected a list of services');
        }
      } else {
        throw Exception('Failed to load services: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching services: $e');
      // Optionally, show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load services')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المتجر'),
      ),
      body: services.isEmpty
          ? Center(child: CircularProgressIndicator())
          : GridView.builder(
        padding: EdgeInsets.all(8.0), // Add padding around the grid
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Number of columns in the grid
          crossAxisSpacing: 8.0, // Spacing between columns
          mainAxisSpacing: 8.0, // Spacing between rows
          childAspectRatio: 0.8, // Width to height ratio of each item
        ),
        itemCount: services.length,
        itemBuilder: (context, index) {
          return ServiceCard(service: services[index]);
        },
      ),
    );
  }
}
class ServiceCard extends StatelessWidget {
  final Service service;

  ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.9; // 20% of screen width
    return SizedBox(
      width: cardWidth, // Set dynamic width for the card
      child: Card(
        margin: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Expanded
            Expanded(
              flex: 1, // Give the image 2 parts of the available space
              child: Container(
                width: double.infinity, // Make the image take full width
                child: Image.network(
                  service.imageUrl,
                  fit: BoxFit.cover, // Ensure the image covers the container
                ),
              ),
            ),
            // Text content with Expanded
            Expanded(
              flex: 1, // Give the text 1 part of the available space
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1, // Limit title to one line
                      overflow: TextOverflow.ellipsis, // Add ellipsis if text overflows
                    ),
                    SizedBox(height: 4),
                    Text(
                      service.description,
                      style: TextStyle(fontSize: 14),
                      maxLines: 2, // Limit description to two lines
                      overflow: TextOverflow.ellipsis, // Add ellipsis if text overflows
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${service.price} / ${service.duration}',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}