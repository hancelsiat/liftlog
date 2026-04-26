
  List<Widget> _buildActionButtons(User user, BuildContext context) {
    List<Widget> buttons = [];

    if (user.role == UserRole.trainer) {
      if (!user.isApproved) {
        // Show Approve/Reject buttons for unapproved trainers
        if (user.credentialImageUrl.isNotEmpty) {
          buttons.add(
            IconButton(
              icon: const Icon(Icons.badge_outlined, color: Colors.blue),
              tooltip: 'View Credential',
              onPressed: () => _viewCredential(user.credentialImageUrl),
            ),
          );
        }
        buttons.add(
          ElevatedButton(
            onPressed: () => _approveTrainer(user.id, true, context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        );
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          ElevatedButton(
            onPressed: () => _showRejectionDialog(context, user.id),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        );
      } else {
        // Show standard edit/delete for approved trainers
        buttons.add(
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.green),
            tooltip: 'Edit User',
            onPressed: () => _editUser(context, user),
          ),
        );
        buttons.add(
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete User',
            onPressed: () => _deleteUser(context, user.id),
          ),
        );
      }
    } else if (user.role != UserRole.admin) {
      // Show standard edit/delete for members
      buttons.add(
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.green),
          tooltip: 'Edit User',
          onPressed: () => _editUser(context, user),
        ),
      );
      buttons.add(
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete User',
          onPressed: () => _deleteUser(context, user.id),
        ),
      );
    }
    // Admins have no actions against them

    return buttons;
  }

  void _viewCredential(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open credential URL: $url')),
      );
    }
  }
