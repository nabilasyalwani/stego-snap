import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stego_snap/screens/nav_page.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/widgets/custom_button.dart';

class ResultDecodePage extends StatelessWidget {
  final String decodedText;
  final String? stegoImagePath;
  final String? stegoImageTitle;

  const ResultDecodePage({
    super.key,
    this.decodedText = 'This is your secret data',
    this.stegoImagePath,
    this.stegoImageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NavPage()),
          ),
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 25.0),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgroundCreate.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              'Secret Content Revealed!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            if (stegoImagePath != null) ...[
              SizedBox(
                height: 200,
                child: Image.network(stegoImagePath!, fit: BoxFit.contain),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              stegoImageTitle ?? 'Decoded from your snap',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25.0),
                decoration: BoxDecoration(
                  color: AppColors.purpleField,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          color: Colors.white,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Secret data: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: decodedText),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              icon: Icons.home_outlined,
              onTap: () => Navigator.pop(context),
              height: 65,
              width: double.infinity,
              borderRadius: 50.0,
              label: 'Back to Home',
              fontSize: 18,
              fontColor: Colors.white,
              backgroundColor: AppColors.transparentPurpleButton,
            ),
          ],
        ),
      ),
    );
  }
}
