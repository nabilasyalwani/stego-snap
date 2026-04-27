import 'package:flutter/material.dart';
import 'package:stego_snap/utils/colors.dart';
import 'package:stego_snap/screens/home_page.dart';
import 'package:stego_snap/screens/notification_page.dart';
import 'package:stego_snap/screens/encode_page.dart';
import 'package:stego_snap/screens/decode_page.dart';
import 'package:stego_snap/widgets/custom_iconbutton.dart';
import 'package:stego_snap/widgets/buttom_sheet_container.dart';
import 'package:stego_snap/widgets/buttom_sheet_header.dart';

class NavPage extends StatefulWidget{
  const NavPage({super.key});

  @override
  State<NavPage> createState() => _NavPageState();
}

class _NavPageState extends State<NavPage>{
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomePage(),
    const NotificationPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context){
    return(Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgroundHome.png',
              fit: BoxFit.cover,
            ),
          ),
          IndexedStack(
            index: _selectedIndex,
            children: [
              SafeArea(child: _widgetOptions[0]),
              SafeArea(child: _widgetOptions[1]),
            ]
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildCustomNavBar(),
          )
        ]
      )
    ));
  }

  Widget _buildCustomNavBar(){
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.navBottom,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 5),
          )
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home, Icons.home_outlined),
          // _buildCreateButton(),
          CustomIconButton(
            onTap: () => _showCreateModal(context),
            width: 65,
            height: 65,
            shape: BoxShape.circle,
            gradient: LinearGradient(
            colors: [AppColors.purpleNavButton, AppColors.purpleButton],
              begin: Alignment.center,
              end: Alignment.center,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 148, 68, 162),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
            fontColor: Colors.white,
            icon: Icons.add,
            iconSize: 32,
          ),
          _buildNavItem(1, Icons.notifications, Icons.notifications_outlined),
        ]
      )
    );
  }

  Widget _buildNavItem(int index, IconData filledIcon, IconData outlinedIcon){
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Icon( isSelected ? filledIcon : outlinedIcon,
        size: 32, 
        color: Colors.white,
      )
    );
  }

  void _showCreateModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BottomSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomSheetHeader(
                iconSize: 32,
                title: "Start creating now",
                onClose: () => Navigator.pop(context),
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.create_outlined,
                    label: "Encode",
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => EncodePage()),
                    ),
                  ),
                  _buildActionButton(
                    icon: Icons.find_in_page_outlined,
                    label: "Decode",
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => DecodePage()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return CustomIconButton(
      icon: icon,
      label: label,
      onTap: onTap,
      height: 75,
      width: 75,
      backgroundColor: AppColors.purpleField,
      borderRadius: 20,
      fontColor: Colors.white,
      iconSize: 28,
    );
  }
}
