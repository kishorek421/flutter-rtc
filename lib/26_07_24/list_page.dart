import 'package:flutter/material.dart';
import 'package:flutter_rtc/26_07_24/add_user_page.dart';
import 'package:flutter_rtc/26_07_24/chat_page.dart';
import 'package:flutter_rtc/26_07_24/models/user.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddUserPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: Hive.openBox<User>('users'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            var box = Hive.box<User>('users');
            return ListView.builder(
              itemCount: box.length,
              itemBuilder: (context, index) {
                var user = box.getAt(index) as User;
                return ListTile(
                  title: Text(user.mobileNumber),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(user: user),
                      ),
                    );
                  },
                );
              },
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
