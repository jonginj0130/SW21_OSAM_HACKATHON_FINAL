import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mypt/components/custom_textfield_form.dart';
import 'package:mypt/components/google_signin_button.dart';
import 'package:mypt/firebase/auth_database.dart';
import 'package:mypt/firebase/authcheck.dart';
import 'package:mypt/screens/home_page.dart';
import 'package:mypt/screens/main_page.dart';
import 'package:mypt/theme.dart';

class RegistrationPage extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final _userNameTextController = TextEditingController();
  final _passwordTextController = TextEditingController();
  final _EmailTextController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final mediaquery = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'images/logo_mypt.png',
                  height: mediaquery.height * 0.2,
                  width: mediaquery.width * 0.8,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Registration',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                _userNameTextField(),
                _passwordTextField(),
                _EmailTextField(),
                _buildDivider(),
                _buildRegisterButton(mediaquery),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Padding _passwordTextField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: CustomTextFieldForm(
        text: 'Password',
        fValidate: (value) => value!.isEmpty ? "Please enter password" : null,
        tController: _passwordTextController,
      ),
    );
  }

  Padding _EmailTextField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: CustomTextFieldForm(
        text: 'Email',
        fValidate: (value) => value!.isEmpty ? "Please enter Email" : null,
        tController: _EmailTextController,
      ),
    );
  }

  Padding _userNameTextField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: CustomTextFieldForm(
        text: 'Username',
        fValidate: (value) => value!.isEmpty ? "Please enter username" : null,
        tController: _userNameTextController,
      ),
    );
  }

  Widget _buildRegisterButton(Size mediaquery) {
    return Container(
      width: mediaquery.width,
      child: TextButton(
        onPressed: () async {
          try {
            UserCredential userCredential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                    email: _EmailTextController.text,
                    password: _passwordTextController.text);
            var currentUser = FirebaseAuth.instance.currentUser;
            print(currentUser!.uid);
          } on FirebaseAuthException catch (e) {
            if (e.code == 'weak-password') {
              flutterToast('password is too weak');
              // print('The password provided is too weak.');
            } else if (e.code == 'email-already-in-use') {
              flutterToast('email is already exits');
              // print('The account already exists for that email.');
            }
          } catch (e) {
            print(e);
          }
          var currentUser = FirebaseAuth.instance.currentUser;
          String uid_name = currentUser!.uid;
          FirebaseFirestore.instance.collection('user_file').doc(uid_name).set({
            'uid': currentUser.uid,
            'email': currentUser.email,
            'name': _userNameTextController.text
          });
          FirebaseFirestore.instance
              .collection('leaderboard_DB')
              .doc(uid_name)
              .set({
            'name': _userNameTextController.text,
            'date': 2110,
            'push_up': 0,
            'squrt': 0,
            'pull_up': 0,
            'score': 0
          });

          Get.to(HomePage());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Text(
            'Register',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 15.0,
        left: 15.0,
        right: 15.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                thickness: 2,
              ),
            ),
          ),
          Text('OR'),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                thickness: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void flutterToast(_text_toast) {
  Fluttertoast.showToast(
    msg: _text_toast,
    gravity: ToastGravity.BOTTOM,
    fontSize: 20.0,
    textColor: Colors.white,
    toastLength: Toast.LENGTH_SHORT,
  );
}
