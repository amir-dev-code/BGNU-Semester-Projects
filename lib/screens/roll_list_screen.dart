import 'package:flutter/material.dart';
import 'complaint_form.dart';

class RollListScreen extends StatelessWidget {
  // Default list of roll numbers
  final List<String> defaultRollNumbers = [
    'BSCSF23E01',
    'BSCSF23E02',
    'BSCSF23E03',
    'BSCSF23E04',
    'BSCSF23E05',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('University Complaint Portal'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Your Roll Number',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Please select your roll number to access the complaint portal:',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              SizedBox(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: defaultRollNumbers.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.person, color: Colors.blue),
                        title: Text(
                          defaultRollNumbers[index],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ComplaintForm(
                                rollNumber: defaultRollNumbers[index],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
