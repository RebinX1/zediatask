import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zediatask/models/models.dart';
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/screens/home/dashboard_tab.dart';
import 'package:zediatask/screens/home/leaderboard_tab.dart';
import 'package:zediatask/screens/home/profile_tab.dart';
import 'package:zediatask/screens/home/tasks_tab.dart';
import 'package:zediatask/screens/task/create_task_screen.dart';
import 'package:zediatask/utils/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const TasksTab(),
    const LeaderboardTab(),
    const ProfileTab(),
  ];

  final List<String> _tabTitles = [
    'Dashboard',
    'Tasks',
    'Leaderboard',
    'Profile',
  ];
  
  final List<IconData> _tabIcons = [
    Icons.dashboard_rounded,
    Icons.task_rounded,
    Icons.leaderboard_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRoleAsync = ref.watch(userRoleProvider);
    final Size size = MediaQuery.of(context).size;
    
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _tabIcons[_currentIndex],
              color: AppTheme.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              _tabTitles[_currentIndex],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        actions: [
          // Only show the add task button for managers and admins on the tasks tab
          if (_currentIndex == 1)
            userRoleAsync.when(
              data: (role) {
                if (role == UserRole.manager || role == UserRole.admin) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(30),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CreateTaskScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.add_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'New Task',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _tabs[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _tabs.length, 
                (index) => _buildNavItem(index, size)
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(int index, Size size) {
    bool isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        if (_currentIndex != index) {
          setState(() {
            _currentIndex = index;
          });
          _animationController.reset();
          _animationController.forward();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size.width * 0.2,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _tabIcons[index],
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              _tabTitles[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 