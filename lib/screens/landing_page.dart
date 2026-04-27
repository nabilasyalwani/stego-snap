import 'package:flutter/material.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/screens/login_page.dart';
import 'package:stego_snap/screens/signup_page.dart';
import 'package:stego_snap/widgets/custom_link.dart';

class LandingPage extends StatelessWidget{
  const LandingPage({super.key});
  @override
  Widget build(BuildContext context){
    return(Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/startingpage.png'),
            fit: BoxFit.cover,
          ),          
        ),
        child: Padding(
          padding: EdgeInsets.all(36.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("STEGO SNAP",
                    style: TextStyle(
                      fontFamily: "ZenDots",
                      fontSize: 36,
                      color: Colors.white,
                    )
                  ),
                  SizedBox(height: 10),
                  Column(
                    children: [
                      Text("The best way to hide your",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 16,
                          color: Colors.white,
                        )
                      ),
                      SizedBox(height: 4),
                      Text("message",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          fontSize: 16,
                          color: Colors.white,
                        )
                      ),
                    ]   
                  )              
                ]
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignupPage(),
                      )
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purpleButton,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,  
                    ),
                    child: Text(
                      "Get Started",
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkPurpleText,
                      )
                    ),
                  ),
                  SizedBox(height: 6),
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
                ]
              )
            ]
          )
        )
      ), 
    ));
  }
}