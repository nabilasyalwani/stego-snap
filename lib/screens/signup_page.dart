import 'package:flutter/material.dart';
import 'package:stego_snap/screens/login_page.dart';
import 'package:stego_snap/screens/landing_page.dart';
import 'package:stego_snap/services/auth_service.dart';
import 'package:stego_snap/widgets/custom_textfield.dart';
import 'package:stego_snap/widgets/custom_link.dart';
import 'package:stego_snap/widgets/custom_button.dart';
import 'package:stego_snap/utils/colors.dart';

class SignupPage extends StatefulWidget{
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>{
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String fullName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String error = '';
  bool _isPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;

  void _tryRegister() async {
    if (_formKey.currentState!.validate()) {
      if (password != confirmPassword) {
        setState(() {
          error = 'Passwords do not match';
        });
        return;
      }
      setState(() {
        error = '';
      });

      dynamic result =
          await _auth.registerWithEmailAndPassword(fullName, email, password);

      if (!mounted) return;
      if (result == null) {
        setState(() {
          error = 'Failed to register. Please use a valid email.';
        });
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context){
    return(Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LandingPage()),
          ),
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 30),
        )
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
            Text("Sign Up",
              style: TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.bold,
                fontSize: 35,
                color: Colors.white,
              )
            ),
            SizedBox(height: 32),
            Form(
              key: _formKey, 
              child: Column(
                children: [
                  CustomTextField(
                    hint: "Full Name",
                    icon: Icons.person_outline,
                    onChanged: (val) => fullName = val,
                    validator: (val) => val!.isEmpty ? 'Enter your full name' : null,
                  ),
                  SizedBox(height: 16),
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
                            _isPasswordObscure =
                                !_isPasswordObscure;
                          });
                        },
                      ), 
                    ),
                  ),
                  SizedBox(height: 16),
                  CustomTextField(
                    hint: 'Confirm password',
                    icon: Icons.lock_outline,
                    obscureText: _isConfirmPasswordObscure,
                    onChanged: (val) => confirmPassword = val,
                    validator: (val) => val!.isEmpty
                        ? 'Confirm your password'
                        : null,
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: IconButton(
                        icon: Icon(
                          _isConfirmPasswordObscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordObscure =
                                !_isConfirmPasswordObscure;
                          });
                        },
                      ), 
                    ),                        
                  ),
                  SizedBox(height: 32),
                  CustomButton(
                    onTap: _tryRegister,
                    height: 65,
                    width: double.infinity,
                    borderRadius: 50.0,
                    label: 'Sign Up',
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
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    label: "Already have an account?",
                    labelLink: "Log In",
                    fontSize: 16,
                    fontFamily: "Poppins",
                  ),
                  if (error.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      error,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ]
        )
      )
    ));
  }
}