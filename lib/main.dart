import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MeeshoApp());

const plum = Color(0xFFA51D86);
const ink = Color(0xFF292735);
const muted = Color(0xFF858394);
const line = Color(0xFFECEAF0);
const green = Color(0xFF078B68);

class MeeshoApp extends StatefulWidget {
  const MeeshoApp({super.key});

  @override
  State<MeeshoApp> createState() => _MeeshoAppState();
}

class _MeeshoAppState extends State<MeeshoApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  int tab = 0;
  String category = 'All';
  String query = '';
  String sort = 'Recommended';
  final Set<int> favorites = {};
  final Map<int, int> cart = {};
  final List<OrderRecord> orders = [];
  bool ordersLoaded = false;
  String? profileName;
  String? profilePhone;
  bool profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadOrders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _requestNotificationPermission();
      });
    });
  }

  Future<void> _loadProfile() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final name = preferences.getString('profile_name');
      final phone = preferences.getString('profile_phone');
      if (!mounted) return;
      setState(() {
        profileName = name;
        profilePhone = phone;
        profileLoaded = true;
      });
    } on MissingPluginException catch (error) {
      debugPrint(
        'Profile storage is not registered. Fully relaunch the app. $error',
      );
      if (mounted) setState(() => profileLoaded = true);
    }
  }

  Future<void> _loadOrders() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedOrders = preferences.getString('shop_orders');
      final records = savedOrders == null
          ? <OrderRecord>[]
          : (jsonDecode(savedOrders) as List<dynamic>)
                .map(
                  (entry) =>
                      OrderRecord.fromJson(entry as Map<String, dynamic>),
                )
                .toList();
      if (!mounted) return;
      setState(() {
        orders
          ..clear()
          ..addAll(records);
        ordersLoaded = true;
      });
    } on MissingPluginException catch (error) {
      debugPrint(
        'Order storage is not registered. Fully relaunch the app. $error',
      );
      if (mounted) setState(() => ordersLoaded = true);
    } on FormatException catch (error) {
      debugPrint('Saved order history could not be read: $error');
      if (mounted) setState(() => ordersLoaded = true);
    }
  }

  Future<void> _saveOrders() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'shop_orders',
        jsonEncode(orders.map((order) => order.toJson()).toList()),
      );
    } on MissingPluginException catch (error) {
      debugPrint(
        'Order storage is not registered. Fully relaunch the app. $error',
      );
    }
  }

  Future<void> _editProfile() async {
    final isSignIn = profilePhone == null;
    final details = await showModalBottomSheet<Map<String, String>>(
      context: navigatorKey.currentContext!,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileForm(
        initialName: profileName ?? '',
        initialPhone: profilePhone ?? '',
        isEditing: profilePhone != null,
      ),
    );
    if (details == null) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('profile_name', details['name']!);
    await preferences.setString('profile_phone', details['phone']!);
    if (!mounted) return;
    setState(() {
      profileName = details['name'];
      profilePhone = details['phone'];
      profileLoaded = true;
    });
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(isSignIn ? 'Signed in on this device' : 'Profile saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('profile_name');
    await preferences.remove('profile_phone');
    if (!mounted) return;
    setState(() {
      profileName = null;
      profilePhone = null;
    });
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await Permission.notification.request();
    } on MissingPluginException catch (error) {
      debugPrint(
        'Notification permission plugin is not registered. '
        'Fully stop and relaunch the app after adding the plugin. $error',
      );
    }
  }

  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  List<Product> get visibleProducts {
    var items = products.where((p) {
      final matchesCategory = category == 'All' || p.category == category;
      final matchesQuery =
          query.isEmpty ||
          '${p.name} ${p.category}'.toLowerCase().contains(query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
    if (sort == 'Price: Low to high') {
      items.sort((a, b) => a.price.compareTo(b.price));
    } else if (sort == 'Top rated') {
      items.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return items;
  }

  void addToCart(Product product) {
    setState(() => cart[product.id] = (cart[product.id] ?? 0) + 1);
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} added to your cart'),
          backgroundColor: ink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void openProduct(Product product) {
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          onOpenProduct: openProduct,
          isFavorite: favorites.contains(product.id),
          onFavorite: () => setState(() {
            favorites.contains(product.id)
                ? favorites.remove(product.id)
                : favorites.add(product.id);
          }),
          onAdd: () => addToCart(product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Meesho',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: plum, primary: plum),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: tab,
            children: [_home(), _categories(), _orders(), _account()],
          ),
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _home() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _search()),
        if (query.isEmpty && category == 'All') ...[
          SliverToBoxAdapter(child: _categoryRail()),
          SliverToBoxAdapter(child: _promo()),
          SliverToBoxAdapter(child: _benefits()),
          SliverToBoxAdapter(
            child: _sectionHeading('Picked for you', 'See all'),
          ),
        ] else
          SliverToBoxAdapter(
            child: _sectionHeading(
              query.isNotEmpty ? 'Search results' : category,
              '${visibleProducts.length} items',
            ),
          ),
        if (visibleProducts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No products found',
                style: TextStyle(color: muted, fontSize: 16),
              ),
            ),
          )
        else
          SliverToBoxAdapter(child: _filterBar()),
        if (visibleProducts.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(
                    product: visibleProducts[index],
                    favorite: favorites.contains(visibleProducts[index].id),
                    onTap: () => openProduct(visibleProducts[index]),
                    onFavorite: () => setState(() {
                      final id = visibleProducts[index].id;
                      favorites.contains(id)
                          ? favorites.remove(id)
                          : favorites.add(id);
                    }),
                  ),
                  childCount: visibleProducts.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.crossAxisExtent > 650 ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.61,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
    child: Row(
      children: [
        const MeeshoLogoMark(size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'meesho',
                style: TextStyle(
                  color: plum,
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profileName == null
                    ? 'Hello, let’s shop!'
                    : 'Hello, ${profileName!.split(' ').first}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Wishlist',
          onPressed: () => _showFavorites(),
          icon: Icon(Icons.favorite_border_rounded, color: ink, size: 27),
        ),
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              tooltip: 'Shopping bag',
              onPressed: () => _showCart(),
              icon: const Icon(
                Icons.shopping_cart_outlined,
                color: ink,
                size: 26,
              ),
            ),
            if (cartCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 1, top: 1),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: plum,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$cartCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _search() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    child: TextField(
      onChanged: (value) => setState(() => query = value.trim()),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by keyword or product ID',
        hintStyle: const TextStyle(color: Color(0xFFA5A2B1), fontSize: 14),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFFA5A2B1),
          size: 25,
        ),
        suffixIcon: const Icon(
          Icons.camera_alt_outlined,
          color: Color(0xFFA5A2B1),
        ),
        filled: true,
        fillColor: const Color(0xFFFCFBFD),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE0DDE8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE0DDE8), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: plum, width: 1.5),
        ),
      ),
    ),
  );

  Widget _categoryRail() => SizedBox(
    height: 112,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final item = categories[index];
        return InkWell(
          onTap: () => setState(
            () => category = item.name == 'Categories' ? 'All' : item.filter,
          ),
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 76,
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: line),
                  ),
                  child: Center(
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _promo() => Container(
    margin: const EdgeInsets.fromLTRB(15, 0, 15, 12),
    height: 102,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xFFF1FBF5), Color(0xFFFFF0FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFFE8D8EA)),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -4,
          top: 1,
          bottom: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=450&q=80',
              width: 154,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(width: 130),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Colors.white, Colors.white70, Colors.transparent],
              stops: [0, .49, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A little treat for you',
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: const TextSpan(
                  style: TextStyle(color: green),
                  children: [
                    TextSpan(
                      text: '₹60 OFF',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: '  on your first order',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Fresh finds. Happy prices.',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _benefits() => Container(
    margin: const EdgeInsets.fromLTRB(15, 0, 15, 19),
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7FC),
      border: Border.all(color: const Color(0xFFEED9EB)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: const [
        _Benefit(icon: '📦', title: '7 Days', subtitle: 'Easy returns'),
        _Benefit(icon: '💵', title: 'Cash on', subtitle: 'Delivery'),
        _Benefit(icon: '🏷️', title: 'Lowest', subtitle: 'Prices'),
      ],
    ),
  );

  Widget _sectionHeading(String title, String action) => Padding(
    padding: const EdgeInsets.fromLTRB(17, 5, 17, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ink,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            color: plum,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _filterBar() => Container(
    margin: const EdgeInsets.only(bottom: 13),
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: line),
        bottom: BorderSide(color: line),
      ),
    ),
    child: Row(
      children: [
        _filterButton(
          Icons.swap_vert,
          sort == 'Recommended' ? 'Sort' : 'Price',
          () => _chooseSort(),
        ),
        _filterButton(
          Icons.keyboard_arrow_down,
          category == 'All' ? 'Category' : category,
          () => _chooseCategory(),
        ),
        _filterButton(
          Icons.keyboard_arrow_down,
          'Gender',
          () => _chooseGender(),
        ),
        _filterButton(Icons.tune, 'Filters', () => _chooseSort()),
      ],
    ),
  );

  Widget _filterButton(IconData icon, String label, VoidCallback onPressed) =>
      Expanded(
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: ink),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _chooseSort() async {
    final value = await showModalBottomSheet<String>(
      context: navigatorKey.currentContext!,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(17),
              child: Text(
                'Sort your finds',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in [
              'Recommended',
              'Price: Low to high',
              'Top rated',
            ])
              ListTile(
                title: Text(option),
                trailing: sort == option
                    ? const Icon(Icons.check, color: plum)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) setState(() => sort = value);
  }

  Future<void> _chooseCategory() async {
    final value = await showModalBottomSheet<String>(
      context: navigatorKey.currentContext!,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(17),
              child: Text(
                'Shop a category',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in [
              'All',
              'Women',
              'Men',
              'Kids',
              'Beauty',
              'Footwear',
              'Home',
              'Jewellery',
            ])
              ListTile(
                title: Text(option),
                trailing: category == option
                    ? const Icon(Icons.check, color: plum)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) setState(() => category = value);
  }

  Future<void> _chooseGender() async {
    final value = await showModalBottomSheet<String>(
      context: navigatorKey.currentContext!,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(17),
              child: Text(
                'Shop by gender',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in ['All', 'Women', 'Men', 'Kids'])
              ListTile(
                title: Text(option),
                trailing: category == option
                    ? const Icon(Icons.check, color: plum)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) setState(() => category = value);
  }

  Widget _categories() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 23, 20, 5),
        child: Text(
          'Shop by category',
          style: TextStyle(
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Text(
          'Little finds for every kind of you',
          style: TextStyle(color: muted, fontSize: 14),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.16,
          ),
          itemCount: categories.length - 1,
          itemBuilder: (context, index) {
            final item = categories[index + 1];
            return InkWell(
              onTap: () => setState(() {
                category = item.filter;
                tab = 0;
              }),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: line),
                ),
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 38)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: plum,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _orders() {
    if (!ordersLoaded) {
      return const Center(child: CircularProgressIndicator(color: plum));
    }
    if (orders.isEmpty) {
      return _simplePage(
        Icons.inventory_2_outlined,
        'Your orders',
        'Your next great find is just a tap away.',
        'Start shopping',
        () => setState(() => tab = 0),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 25, 17, 24),
      children: [
        const Text(
          'My Orders',
          style: TextStyle(
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
          style: const TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 17),
        for (final order in orders) _orderCard(order),
      ],
    );
  }

  Widget _orderCard(OrderRecord order) {
    final orderNumber = order.id.substring(order.id.length - 6);
    final date = order.placedAt;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    final entries = order.items.entries.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #$orderNumber',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Order placed',
                  style: TextStyle(
                    color: green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Placed on $dateLabel',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(height: 1, color: line),
          ),
          for (final entry in entries.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      products[entry.key].image,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFFF8F1F6),
                        child: const Icon(
                          Icons.checkroom,
                          color: plum,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          products[entry.key].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Qty ${entry.value}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${products[entry.key].price * entry.value}',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (entries.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '+ ${entries.length - 3} more items',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
          const Divider(height: 1, color: line),
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ),
                const Text(
                  'Order total  ',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                Text(
                  '₹${order.total}',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _account() {
    if (!profileLoaded) {
      return const Center(child: CircularProgressIndicator(color: plum));
    }
    if (profilePhone == null) {
      return _simplePage(
        Icons.person_outline_rounded,
        'Your account',
        'Sign in on this device to keep your profile details handy.',
        'Sign in',
        _editProfile,
      );
    }

    final initials = profileName!.trim().split(RegExp(r'\s+'));
    final avatarText = initials.length > 1
        ? '${initials.first[0]}${initials.last[0]}'.toUpperCase()
        : initials.first.substring(0, 1).toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 32),
      children: [
        const Text(
          'Your account',
          style: TextStyle(
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your details, all in one place',
          style: TextStyle(color: muted, fontSize: 14),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5FB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1DDEB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 29,
                backgroundColor: plum,
                child: Text(
                  avatarText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileName!,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+91 $profilePhone',
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_outlined, color: plum),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _accountAction(
          Icons.person_outline_rounded,
          'Edit profile',
          'Update your name or phone number',
          _editProfile,
        ),
        const SizedBox(height: 9),
        _accountAction(
          Icons.favorite_border_rounded,
          'Wishlist',
          '${favorites.length} saved items',
          _showFavorites,
        ),
        const SizedBox(height: 9),
        _accountAction(
          Icons.logout_rounded,
          'Sign out',
          'Remove this profile from this device',
          _signOut,
        ),
        const SizedBox(height: 14),
        const Text(
          'This profile is saved on this device. No internet or OTP is needed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _accountAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: plum, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    ),
  );

  Widget _simplePage(
    IconData icon,
    String title,
    String subtitle,
    String button,
    VoidCallback onPressed,
  ) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1FB),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: plum),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              color: ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: plum),
            child: Text(button),
          ),
        ],
      ),
    ),
  );

  Widget _bottomNav() {
    const labels = ['Home', 'Categories', 'My Orders', 'Account'];
    const icons = [
      Icons.home_outlined,
      Icons.grid_view_rounded,
      Icons.inventory_2_outlined,
      Icons.face_3_outlined,
    ];
    const selected = [
      Icons.home_rounded,
      Icons.grid_view_rounded,
      Icons.inventory_2_rounded,
      Icons.face_3_rounded,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 61,
          child: Row(
            children: List.generate(labels.length, (i) {
              final active = tab == i;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => tab = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? selected[i] : icons[i],
                        size: 22,
                        color: active ? plum : const Color(0xFF858393),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 9,
                          color: active ? plum : const Color(0xFF777585),
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showFavorites() => showModalBottomSheet<void>(
    context: navigatorKey.currentContext!,
    isScrollControlled: true,
    builder: (_) => _collectionSheet('Your wishlist', favorites.toList()),
  );
  void _showCart() => navigatorKey.currentState!.push(
    MaterialPageRoute(
      builder: (_) => CartPage(
        items: Map<int, int>.of(cart),
        wishlist: Set<int>.of(favorites),
        onCartChanged: (items) => setState(() {
          cart
            ..clear()
            ..addAll(items);
        }),
        onMoveToWishlist: (id) => setState(() => favorites.add(id)),
        onRemoveFromWishlist: (id) => setState(() => favorites.remove(id)),
        onCheckout: () {
          if (cart.isEmpty) return;
          final order = OrderRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            placedAt: DateTime.now(),
            items: Map<int, int>.of(cart),
          );
          setState(() {
            orders.insert(0, order);
            ordersLoaded = true;
            cart.clear();
          });
          _saveOrders();
          messengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Your order is on its way!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    ),
  );
  Widget _collectionSheet(String title, List<int> ids) => SafeArea(
    child: SizedBox(
      height: MediaQuery.of(context).size.height * .72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (ids.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Save the things you love here',
                  style: TextStyle(color: muted),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: ids
                    .map(
                      (id) => ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            products[id].image,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          products[id].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('₹${products[id].price}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite, color: plum),
                          onPressed: () => setState(() => favorites.remove(id)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    ),
  );
}

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.items,
    required this.wishlist,
    required this.onCartChanged,
    required this.onMoveToWishlist,
    required this.onRemoveFromWishlist,
    required this.onCheckout,
  });

  final Map<int, int> items;
  final Set<int> wishlist;
  final ValueChanged<Map<int, int>> onCartChanged;
  final ValueChanged<int> onMoveToWishlist;
  final ValueChanged<int> onRemoveFromWishlist;
  final VoidCallback onCheckout;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final priceKey = GlobalKey();
  late Map<int, int> items;
  late Set<int> wishlist;
  final Map<int, String> sizes = {};
  String deliveryLocation = 'Bengaluru - 560064';
  bool showWishlist = false;

  @override
  void initState() {
    super.initState();
    items = Map<int, int>.of(widget.items);
    wishlist = Set<int>.of(widget.wishlist);
  }

  int get itemCount => items.values.fold(0, (sum, value) => sum + value);
  int get orderTotal => items.entries.fold(
    0,
    (sum, item) => sum + products[item.key].price * item.value,
  );
  int get mrpTotal => items.entries.fold(
    0,
    (sum, item) => sum + products[item.key].oldPrice * item.value,
  );

  void _setQuantity(int id, int quantity) {
    setState(() {
      if (quantity <= 0) {
        items.remove(id);
      } else {
        items[id] = quantity;
      }
    });
    widget.onCartChanged(Map<int, int>.of(items));
  }

  void _moveToWishlist(int id) {
    setState(() {
      wishlist.add(id);
      items.remove(id);
    });
    widget.onMoveToWishlist(id);
    widget.onCartChanged(Map<int, int>.of(items));
  }

  Future<void> _selectQuantity(int id) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select quantity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (var quantity = 1; quantity <= 5; quantity++)
              ListTile(
                title: Text('$quantity'),
                trailing: items[id] == quantity
                    ? const Icon(Icons.check, color: plum)
                    : null,
                onTap: () => Navigator.pop(context, quantity),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) _setQuantity(id, selected);
  }

  Future<void> _selectSize(int id) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select size',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final size in ['Free Size', 'S', 'M', 'L', 'XL', 'XXL'])
              ListTile(
                title: Text(size),
                trailing: (sizes[id] ?? 'Free Size') == size
                    ? const Icon(Icons.check, color: plum)
                    : null,
                onTap: () => Navigator.pop(context, size),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => sizes[id] = selected);
  }

  Future<void> _changeLocation() async {
    final controller = TextEditingController(
      text: RegExp(r'\d{6}$').firstMatch(deliveryLocation)?.group(0) ?? '',
    );
    final pincode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'PIN code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => controller.text.length == 6
                ? Navigator.pop(context, controller.text)
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pincode != null) {
      setState(() => deliveryLocation = 'PIN code $pincode');
    }
  }

  void _showPriceDetails() {
    final target = priceKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount = mrpTotal - orderTotal;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text(
          'CART',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'STEP 1/3',
              style: TextStyle(
                color: Color(0xFF5478D8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: items.isEmpty ? _emptyCart() : _cartContents(discount),
      bottomNavigationBar: items.isEmpty ? null : _bottomCheckout(),
    );
  }

  Widget _emptyCart() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 64, color: plum),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              color: ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Find something lovely at a price you’ll love.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: plum),
            child: const Text('Continue shopping'),
          ),
        ],
      ),
    ),
  );

  Widget _cartContents(int discount) => ListView(
    padding: const EdgeInsets.only(bottom: 10),
    children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF648BE7), size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delivery at $deliveryLocation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _changeLocation,
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                side: const BorderSide(color: Color(0xFF656271)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 9),
      for (final entry in items.entries.toList())
        _cartItem(entry.key, entry.value),
      const SizedBox(height: 8),
      _wishlistSection(),
      const SizedBox(height: 9),
      Container(
        key: priceKey,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Details ($itemCount ${itemCount == 1 ? 'Item' : 'Items'})',
              style: const TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 17),
            _priceLine('Product Price', mrpTotal),
            const SizedBox(height: 11),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Discounts',
                    style: TextStyle(color: green, fontSize: 13),
                  ),
                ),
                Text(
                  '-  ₹$discount',
                  style: const TextStyle(
                    color: green,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: line),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Order Total',
                    style: TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '₹$orderTotal',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD9F5EE),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  '✿  Yay! Your total discount is ₹$discount',
                  style: const TextStyle(
                    color: green,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 9),
      _paymentOffer(),
      const SizedBox(height: 9),
      _cartBenefits(),
      const SizedBox(height: 14),
    ],
  );

  Widget _cartItem(int id, int quantity) {
    final product = products[id];
    final discount =
        ((product.oldPrice - product.price) / product.oldPrice * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    product.image,
                    width: 112,
                    height: 126,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 112,
                      height: 126,
                      color: const Color(0xFFF8F1F6),
                      child: const Icon(Icons.checkroom, color: plum, size: 38),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.tag == 'Mall') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: plum,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '✦ Mall',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: [
                          Text(
                            '₹${product.price}',
                            style: const TextStyle(
                              color: ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (product.oldPrice > product.price)
                            Text(
                              '₹${product.oldPrice}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '$discount% Off',
                            style: const TextStyle(
                              color: green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      if (product.tag == 'Mall') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '⏱ 08h : 16m : 45s',
                            style: TextStyle(
                              color: Color(0xFFE17E44),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      Wrap(
                        spacing: 7,
                        children: [
                          _cartChip(
                            'Size: ${sizes[id] ?? 'Free Size'}',
                            () => _selectSize(id),
                          ),
                          _cartChip(
                            'Qty: $quantity',
                            () => _selectQuantity(id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        product.category == 'Beauty'
                            ? 'No Returns-Only Exchange'
                            : 'Easy returns available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            color: Color(0xFFB8BBC8),
                            size: 18,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Estimated delivery in 4–6 days',
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: line),
          SizedBox(
            height: 39,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _moveToWishlist(id),
                    icon: const Icon(
                      Icons.favorite_border,
                      color: ink,
                      size: 18,
                    ),
                    label: const Text(
                      'Move to Wishlist',
                      style: TextStyle(color: ink, fontSize: 12),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: line),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _setQuantity(id, 0),
                    icon: const Icon(Icons.close, color: ink, size: 18),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: ink, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartChip(String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FB),
        border: Border.all(color: const Color(0xFFE6E5EC)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label  ›',
        style: const TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _wishlistSection() => Container(
    color: Colors.white,
    child: Column(
      children: [
        InkWell(
          onTap: () => setState(() => showWishlist = !showWishlist),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            child: Row(
              children: [
                const Icon(Icons.favorite_border_rounded, color: ink, size: 23),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Wishlist${wishlist.isEmpty ? '' : '  (${wishlist.length})'}',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  showWishlist ? Icons.expand_less : Icons.chevron_right,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
        if (showWishlist)
          if (wishlist.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your wishlist is empty',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            )
          else
            for (final id in wishlist)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    products[id].image,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 46, height: 46),
                  ),
                ),
                title: Text(
                  products[id].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(
                  '₹${products[id].price}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: () {
                    setState(() {
                      wishlist.remove(id);
                      items[id] = 1;
                    });
                    widget.onRemoveFromWishlist(id);
                    widget.onCartChanged(Map<int, int>.of(items));
                  },
                  child: const Text('Add to cart'),
                ),
              ),
      ],
    ),
  );

  Widget _priceLine(String title, int value) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: muted,
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ),
      ),
      Text('+  ₹$value', style: const TextStyle(color: ink, fontSize: 13)),
    ],
  );

  Widget _paymentOffer() => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(14),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9D7DE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'G Pay   PhonePe\nPaytm   UPI',
              style: TextStyle(
                color: Color(0xFF4B4770),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          const SizedBox(width: 10),
          const Expanded(
            flex: 2,
            child: Text(
              'UPTO 12% EXTRA DISCOUNT\non online payments',
              style: TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cartBenefits() => Container(
    color: const Color(0xFFFFF0F9),
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
    child: const Row(
      children: [
        _CartBenefit(icon: '📦', title: '7 Days', subtitle: 'Easy Return'),
        _CartBenefit(icon: '💵', title: 'Cash on', subtitle: 'Delivery'),
        _CartBenefit(icon: '🏷️', title: 'Lowest', subtitle: 'Price'),
      ],
    ),
  );

  Widget _bottomCheckout() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 11),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹$orderTotal',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: _showPriceDetails,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 23),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'VIEW PRICE DETAILS',
                    style: TextStyle(
                      color: plum,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 150,
            height: 48,
            child: FilledButton(
              onPressed: () {
                widget.onCheckout();
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: plum,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CartBenefit extends StatelessWidget {
  const _CartBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 9)),
          ],
        ),
      ],
    ),
  );
}

class MeeshoLogoMark extends StatelessWidget {
  const MeeshoLogoMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF5B0B4B),
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    padding: EdgeInsets.all(size * 0.19),
    child: CustomPaint(painter: _MeeshoMarkPainter()),
  );
}

class _MeeshoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 32;
    final scaleY = size.height / 38;
    canvas.scale(scaleX, scaleY);
    final paint = Paint()
      ..color = const Color(0xFFFF9E00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final mark = Path()
      ..moveTo(5, 33)
      ..lineTo(5, 20)
      ..quadraticBezierTo(5, 12, 13, 20)
      ..lineTo(13, 33)
      ..lineTo(13, 20)
      ..quadraticBezierTo(13, 12, 21, 20)
      ..lineTo(21, 33)
      ..lineTo(21, 20)
      ..quadraticBezierTo(21, 12, 29, 20)
      ..lineTo(29, 33);
    canvas.drawPath(mark, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.isEditing,
  });

  final String initialName;
  final String initialPhone;
  final bool isEditing;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void saveProfile() {
    if (formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D5DE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 21),
                  Text(
                    widget.isEditing
                        ? 'Edit your profile'
                        : 'Welcome to Meesho',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.isEditing
                        ? 'Keep your details up to date.'
                        : 'Add your details to sign in on this device.',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Your name',
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _profileInput(
                      'Enter your name',
                      Icons.person_outline,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: 17),
                  const Text(
                    'Phone number',
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration:
                        _profileInput(
                          '10-digit mobile number',
                          Icons.phone_outlined,
                        ).copyWith(
                          prefixText: '+91  ',
                          prefixStyle: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    validator: (value) =>
                        value == null || value.trim().length != 10
                        ? 'Enter a valid 10-digit number'
                        : null,
                    onFieldSubmitted: (_) => saveProfile(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No OTP needed. Your profile stays on this device.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: plum,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: Text(
                        widget.isEditing ? 'Save changes' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _profileInput(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFA5A2B1), fontSize: 13),
    prefixIcon: Icon(icon, color: muted, size: 20),
    filled: true,
    fillColor: const Color(0xFFFCFBFD),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: plum, width: 1.5),
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });
  final Product product;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAE8EF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  product.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFF8F1F6),
                    child: const Icon(Icons.checkroom, size: 50, color: plum),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: .93),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onFavorite,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: favorite ? plum : ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (product.tag.isNotEmpty)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: const BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(9),
                        ),
                      ),
                      child: Text(
                        product.tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF555261),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${product.price}',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 5),
                    if (product.oldPrice > product.price)
                      Text(
                        '₹${product.oldPrice}',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${product.discount}% off',
                      style: const TextStyle(
                        color: green,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.star, color: Colors.white, size: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '(${product.reviews})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ProductPage extends StatefulWidget {
  const ProductPage({
    super.key,
    required this.product,
    required this.onOpenProduct,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAdd,
  });
  final Product product;
  final ValueChanged<Product> onOpenProduct;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  bool favorite = false;
  @override
  void initState() {
    super.initState();
    favorite = widget.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              favorite = !favorite;
              widget.onFavorite();
            }),
            icon: Icon(
              favorite ? Icons.favorite : Icons.favorite_border,
              color: favorite ? plum : ink,
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: .92,
            child: Image.network(
              p.image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFF8F1F6),
                child: const Icon(Icons.checkroom, size: 80, color: plum),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: plum,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✦ Mall',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.category,
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.name,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${p.price}',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${p.oldPrice}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 15,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${p.discount}% off',
                      style: const TextStyle(
                        color: green,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Discount applied ✓',
                    style: TextStyle(
                      color: green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  '₹${(p.price * .86).round()} with 1 special offer  ›',
                  style: const TextStyle(
                    color: green,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '★  ${p.rating}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${p.reviews} ratings',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(color: line),
                ),
                const Text(
                  'Why you’ll love it',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'A lovely everyday pick at a price that makes you smile. Easy returns within 7 days.',
                  style: TextStyle(color: muted, height: 1.5, fontSize: 14),
                ),
                const SizedBox(height: 24),
                _suggestedProducts(p),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: line)),
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: widget.onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: plum,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Add to bag  ·  ₹${p.price}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestedProducts(Product currentProduct) {
    final suggestions =
        products.where((product) => product.id != currentProduct.id).toList()
          ..sort((a, b) {
            final aRelated = a.category == currentProduct.category;
            final bRelated = b.category == currentProduct.category;
            if (aRelated == bRelated) return 0;
            return aRelated ? -1 : 1;
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 0, 15, 19),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7FC),
            border: Border.all(color: const Color(0xFFEED9EB)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: const [
              _Benefit(icon: '📦', title: '7 Days', subtitle: 'Easy returns'),
              _Benefit(icon: '💵', title: 'Cash on', subtitle: 'Delivery'),
              _Benefit(icon: '🏷️', title: 'Lowest', subtitle: 'Prices'),
            ],
          ),
        ),

        const Text(
          'You may also like',
          style: TextStyle(
            color: ink,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 230,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
          ),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return InkWell(
              onTap: () => widget.onOpenProduct(suggestion),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.network(
                        suggestion.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFFF8F1F6),
                          child: const Icon(
                            Icons.checkroom,
                            color: plum,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 8, 8, 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹${suggestion.price}',
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${suggestion.discount}% off',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: green,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '★ ${suggestion.rating}  ·  ${suggestion.reviews}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final String icon, title, subtitle;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 9)),
          ],
        ),
      ],
    ),
  );
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.placedAt,
    required this.items,
  });

  final String id;
  final DateTime placedAt;
  final Map<int, int> items;

  int get itemCount => items.values.fold(0, (sum, quantity) => sum + quantity);
  int get total => items.entries.fold(
    0,
    (sum, entry) => sum + products[entry.key].price * entry.value,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'placedAt': placedAt.toIso8601String(),
    'items': items.map((id, quantity) => MapEntry(id.toString(), quantity)),
  };

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    final savedItems = Map<String, dynamic>.from(json['items'] as Map);
    return OrderRecord(
      id: json['id'] as String,
      placedAt: DateTime.parse(json['placedAt'] as String),
      items: savedItems.map(
        (id, quantity) => MapEntry(int.parse(id), (quantity as num).toInt()),
      ),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    required this.price,
    required this.oldPrice,
    required this.rating,
    required this.reviews,
    required this.discount,
    this.tag = '',
  });
  final int id;
  final String name, category, image, reviews, tag;
  final int price, oldPrice, discount;
  final double rating;
}

class ShopCategory {
  const ShopCategory(this.name, this.emoji, this.filter, this.color);
  final String name, emoji, filter;
  final Color color;
}

const categories = [
  ShopCategory('Categories', '▦', 'All', Color(0xFFFFF0F8)),
  ShopCategory('Kurtis & Dresses', '👗', 'Women', Color(0xFFFFF1F2)),
  ShopCategory('Kids & Toys', '🧸', 'Kids', Color(0xFFF0F5FF)),
  ShopCategory('Westernwear', '👚', 'Women', Color(0xFFF5F0FF)),
  ShopCategory('Home & Kitchen', '🪴', 'Home', Color(0xFFEFF8F1)),
  ShopCategory('Men Fashion', '👕', 'Men', Color(0xFFF1F5F9)),
  ShopCategory('Beauty', '✨', 'Beauty', Color(0xFFFFF2EB)),
  ShopCategory('Footwear', '👟', 'Footwear', Color(0xFFFFF9E9)),
  ShopCategory('Jewellery', '💛', 'Jewellery', Color(0xFFFFF7DF)),
];

const products = [
  Product(
    id: 0,
    name: 'Everyday cotton kurta set',
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1583391733956-6c78276477e1?auto=format&fit=crop&w=700&q=85',
    price: 510,
    oldPrice: 899,
    rating: 4.2,
    reviews: '2.4 lakh',
    discount: 43,
    tag: 'Bestseller',
  ),
  Product(
    id: 1,
    name: 'Floral printed dress',
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?auto=format&fit=crop&w=700&q=85',
    price: 520,
    oldPrice: 999,
    rating: 4.3,
    reviews: '18,264',
    discount: 48,
    tag: 'Trending',
  ),
  Product(
    id: 2,
    name: 'Classic white shirt',
    category: 'Men',
    image: 'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?auto=format&fit=crop&w=700&q=85',
    price: 421,
    oldPrice: 799,
    rating: 4.1,
    reviews: '9,841',
    discount: 47,
  ),
  Product(
    id: 3,
    name: 'Wireless earbuds with case',
    category: 'Electronics',
    image: 'https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?auto=format&fit=crop&w=700&q=85',
    price: 312,
    oldPrice: 999,
    rating: 4.0,
    reviews: '7,526',
    discount: 69,
    tag: 'Top rated',
  ),
  Product(
    id: 4,
    name: 'Relaxed fit zip hoodie',
    category: 'Men',
    image: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&w=700&q=85',
    price: 297,
    oldPrice: 649,
    rating: 4.1,
    reviews: '4,208',
    discount: 54,
  ),
  Product(
    id: 5,
    name: 'Wildplay chocolate perfume',
    category: 'Beauty',
    image: 'https://images.unsplash.com/photo-1594035910387-fea47794261f?auto=format&fit=crop&w=700&q=85',
    price: 135,
    oldPrice: 399,
    rating: 3.9,
    reviews: '1.8 lakh',
    discount: 66,
    tag: 'Mall',
  ),
  Product(
    id: 6,
    name: 'Everyday comfort sandals',
    category: 'Footwear',
    image: 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&w=700&q=85',
    price: 192,
    oldPrice: 499,
    rating: 4.2,
    reviews: '12,305',
    discount: 62,
  ),
  Product(
    id: 7,
    name: 'Fresh floral body mist',
    category: 'Beauty',
    image: 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&w=700&q=85',
    price: 92,
    oldPrice: 249,
    rating: 4.0,
    reviews: '8,733',
    discount: 63,
  ),
  Product(
    id: 8,
    name: 'Minimal silver pendant set',
    category: 'Jewellery',
    image: 'https://images.unsplash.com/photo-1611652022419-a9419f74343d?auto=format&fit=crop&w=700&q=85',
    price: 159,
    oldPrice: 449,
    rating: 4.1,
    reviews: '3,120',
    discount: 65,
  ),
  Product(
    id: 9,
    name: 'Soft cotton printed kurta',
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=700&q=85',
    price: 294,
    oldPrice: 599,
    rating: 4.3,
    reviews: '5,672',
    discount: 51,
  ),
  Product(
    id: 10,
    name: 'Comfy everyday sneakers',
    category: 'Footwear',
    image: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=700&q=85',
    price: 484,
    oldPrice: 999,
    rating: 4.2,
    reviews: '6,291',
    discount: 52,
  ),
  Product(
    id: 11,
    name: 'Festive silk saree',
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1617627143750-d86bc21e42bb?auto=format&fit=crop&w=700&q=85',
    price: 439,
    oldPrice: 1299,
    rating: 4.4,
    reviews: '21,438',
    discount: 66,
    tag: 'Popular',
  ),
  Product(
    id: 12,
    name: 'Gold-tone bracelet duo',
    category: 'Jewellery',
    image: 'https://images.unsplash.com/photo-1611591437281-460bfbe1220a?auto=format&fit=crop&w=700&q=85',
    price: 175,
    oldPrice: 499,
    rating: 4.0,
    reviews: '2,428',
    discount: 65,
  ),
  Product(
    id: 13,
    name: 'Cute mini bear kids set',
    category: 'Kids',
    image: 'https://images.unsplash.com/photo-1519238263530-99bdd11df2ea?auto=format&fit=crop&w=700&q=85',
    price: 242,
    oldPrice: 599,
    rating: 4.3,
    reviews: '21,055',
    discount: 60,
    tag: 'Trending',
  ),
  Product(
    id: 14,
    name: 'Everyday home planter',
    category: 'Home',
    image: 'https://images.unsplash.com/photo-1485955900006-10f4d324d411?auto=format&fit=crop&w=700&q=85',
    price: 166,
    oldPrice: 349,
    rating: 4.2,
    reviews: '3,749',
    discount: 52,
  ),
  Product(
    id: 15,
    name: 'Fresh glow face wash',
    category: 'Beauty',
    image: 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?auto=format&fit=crop&w=700&q=85',
    price: 214,
    oldPrice: 350,
    rating: 4.2,
    reviews: '24,183',
    discount: 39,
    tag: 'Mall',
  ),
];
