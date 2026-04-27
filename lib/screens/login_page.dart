import 'package:flutter/material.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/screens/signup_page.dart';
import 'package:stego_snap/screens/landing_page.dart';
import 'package:stego_snap/screens/nav_page.dart';
import 'package:stego_snap/services/auth_service.dart';
import 'package:stego_snap/widgets/custom_link.dart';
import 'package:stego_snap/widgets/custom_textfield.dart';
import 'package:stego_snap/widgets/custom_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String fullName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String error = '';
  bool _isPasswordObscure = true;

  void _tryLogin() async {
    if (_formKey.currentState!.validate()) {
      dynamic result = await _auth.signInWithEmailAndPassword(email, password);

      if (!mounted) return;
      if (result == null) {
        setState(() {
          error = 'Could not sign in with those credentials.';
        });
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NavPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return (Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LandingPage()),
          ),
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(32.0),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgroundAuth.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Log In",
              style: TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.bold,
                fontSize: 35,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    hint: "Enter your email",
                    icon: Icons.email_outlined,
                    onChanged: (val) => email = val,
                    validator: (val) => val!.isEmpty ? 'Enter an email' : null,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),
                  CustomTextField(
                    hint: 'Enter password',
                    icon: Icons.lock_outline,
                    obscureText: _isPasswordObscure,
                    onChanged: (val) => password = val,
                    validator: (val) => val!.length < 6
                        ? 'Password must be 6+ characters'
                        : null,
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: IconButton(
                        icon: Icon(
                          _isPasswordObscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordObscure = !_isPasswordObscure;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  CustomButton(
                    onTap: _tryLogin,
                    height: 65,
                    width: double.infinity,
                    borderRadius: 50.0,
                    label: 'Log In',
                    fontSize: 18,
                    fontColor: AppColors.darkPurpleText,
                    gradient: const LinearGradient(
                      colors: [Colors.white, AppColors.purpleButton],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  SizedBox(height: 32),
                  CustomLink(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => SignupPage()),
                      );
                    },
                    label: "Don't have an account?",
                    labelLink: "Sign Up",
                    fontSize: 16,
                    fontFamily: "Poppins",
                  ),
                  if (error.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      error,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
