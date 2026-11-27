import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  List<User> _users = [];
  bool _isLoggedIn = false;
  bool _mustChangePassword = false;
  bool _passwordChangeSkippedThisSession = false;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  List<User> get users => _users;
  bool get isLoggedIn => _isLoggedIn;
  bool get mustChangePassword => _mustChangePassword;
  bool get shouldPromptPasswordChange =>
      _mustChangePassword && !_passwordChangeSkippedThisSession;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool hasRole(UserRole role) => _user?.hasRole(role) ?? false;
  bool get isAdmin => hasRole(UserRole.admin);
  bool get isManager => hasRole(UserRole.manager);
  bool get isCashier => hasRole(UserRole.cashier);

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.login(username, password);
      final userJson = Map<String, dynamic>.from(result['user'] as Map);
      _user = User.fromJson(userJson);
      _isLoggedIn = true;
      _mustChangePassword = _user?.mustChangePassword ?? false;
      _passwordChangeSkippedThisSession = false;

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.logout();
      _user = null;
      _users = [];
      _isLoggedIn = false;
      _mustChangePassword = false;
      _passwordChangeSkippedThisSession = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchUsers() async {
    if (!isAdmin) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await ApiService.getUsers();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser({
    required String username,
    required String email,
    required String password,
    required List<UserRole> roles,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final createdUser = await ApiService.createUser(username, email, password, roles);
      _users = [createdUser, ..._users];
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.changeMyPassword(currentPassword, newPassword);
      _mustChangePassword = false;
      _passwordChangeSkippedThisSession = false;
      if (_user != null) {
        _user = User(
          id: _user!.id,
          username: _user!.username,
          email: _user!.email,
          mobile: _user!.mobile,
          role: _user!.role,
          roles: _user!.roles,
          isActive: _user!.isActive,
          mustChangePassword: false,
          createdAt: _user!.createdAt,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMyProfile({
    required String email,
    required String mobile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await ApiService.updateMyProfile(email: email, mobile: mobile);
      _user = updatedUser;
      _mustChangePassword = _user?.mustChangePassword ?? false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void skipPasswordChangeForSession() {
    if (!_mustChangePassword) {
      return;
    }
    _passwordChangeSkippedThisSession = true;
    notifyListeners();
  }

  Future<bool> adminResetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.adminUpdateUserPassword(userId, newPassword);
      await fetchUsers();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> updateUser({
    required String userId,
    required String username,
    required String email,
    required String mobile,
    required List<UserRole> roles,
    required bool isActive,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await ApiService.updateUser(
        userId,
        username: username,
        email: email,
        mobile: mobile,
        roles: roles,
        isActive: isActive,
      );

      // Update the user in the list
      final index = _users.indexWhere((u) => u.id == userId);
      if (index >= 0) {
        _users[index] = updatedUser;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser({
    required String userId,
    bool hardDelete = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.deleteUser(userId, hardDelete: hardDelete);

      // Remove the user from the list
      _users.removeWhere((u) => u.id == userId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
