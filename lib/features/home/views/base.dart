import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_clone/features/chat/models/recent_chat.dart';
import 'package:whatsapp_clone/features/chat/views/chat.dart';
import 'package:whatsapp_clone/features/home/data/repositories/contact_repository.dart';
import 'package:whatsapp_clone/shared/repositories/firebase_firestore.dart';
import 'package:whatsapp_clone/features/home/views/contacts.dart';
import 'package:whatsapp_clone/shared/models/user.dart';
import 'package:whatsapp_clone/shared/utils/abc.dart';
import '../../../theme/colors.dart';

class HomePage extends ConsumerStatefulWidget {
  final User user;

  const HomePage({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Widget> _floatingButtons;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(_handleTabIndex);

    // Exception needs to be handled for the case - Permission
    FlutterContacts.addListener(_contactsListener);

    _floatingButtons = [
      FloatingActionButton(
        onPressed: () async {
          if (!await ref.read(contactsRepositoryProvider).requestPermission()) {
            final prefs = await SharedPreferences.getInstance();

            if (prefs.getBool('showAppSettingsForContactsPerm') ?? false) {
              return AppSettings.openAppSettings(asAnotherTask: true);
            }

            prefs.setBool('showAppSettingsForContactsPerm', true);
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ContactsPage(
                user: widget.user,
              ),
            ),
          );
        },
        child: const Icon(Icons.chat),
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: AppColors.appBarColor,
            onPressed: () {},
            child: const Icon(Icons.edit),
          ),
          const SizedBox(
            height: 16.0,
          ),
          FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.camera_alt_rounded),
          ),
        ],
      ),
      FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add_call),
      )
    ];

    super.initState();
  }

  void _contactsListener() {
    ref.refresh(contactsRepositoryProvider);
  }

  @override
  void dispose() {
    FlutterContacts.removeListener(_contactsListener);
    _tabController.removeListener(_handleTabIndex);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabIndex() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('WhatsApp'),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.tabColor,
            indicatorWeight: 3.0,
            labelColor: AppColors.tabColor,
            unselectedLabelColor: AppColors.textColor,
            tabs: const [
              Tab(
                text: 'CHATS',
              ),
              Tab(
                text: 'STATUS',
              ),
              Tab(
                text: 'CALLS',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            RecentChats(user: widget.user),
            const Center(
              child: Text('Coming soon'),
            ),
            const Center(
              child: Text('Coming soon'),
            )
          ],
        ),
        floatingActionButton: _floatingButtons[_tabController.index],
      ),
    );
  }
}

class RecentChats extends ConsumerStatefulWidget {
  const RecentChats({
    Key? key,
    required this.user,
  }) : super(key: key);

  final User user;

  @override
  ConsumerState<RecentChats> createState() => _RecentChatsState();
}

class _RecentChatsState extends ConsumerState<RecentChats> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RecentChat>>(
        stream: ref
            .read(firebaseFirestoreRepositoryProvider)
            .getRecentChatStream(widget.user.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }

          final chats = snapshot.data!;
          return ListView.builder(
            itemCount: chats.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              RecentChat chat = chats[index];

              return ListTile(
                onTap: () async {
                  final user1 = await ref
                      .read(firebaseFirestoreRepositoryProvider)
                      .getUserById(chat.message.senderId);

                  final user2 = await ref
                      .read(firebaseFirestoreRepositoryProvider)
                      .getUserById(chat.message.receiverId);

                  if (!mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          self: widget.user,
                          other: widget.user.id == user1!.id ? user2! : user1,
                        ),
                      ),
                      (route) => false);
                },
                leading: CircleAvatar(
                  // radius: 24.0,
                  backgroundImage: NetworkImage(
                    chat.avatarUrl,
                  ),
                ),
                title: Text(
                  chat.name,
                  style: Theme.of(context).textTheme.bodyText2,
                ),
                subtitle: Text(
                  chat.message.content.length > 30
                      ? '${chat.message.content.substring(0, 30)}...'
                      : chat.message.content,
                  style: Theme.of(context).textTheme.caption,
                ),
                trailing: Text(
                  formattedTimestamp(chat.message.timestamp),
                  style: Theme.of(context).textTheme.caption,
                ),
              );
            },
          );
        });
  }
}
