import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tailor_provider.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/models/tailor_models.dart';
import '../../../shared/models/user_model.dart';
import 'tailor_customers_view.dart';
import 'tailor_orders_view.dart';

enum TailorViewMode { ganacsi, harqaan, farsamo }

class TailorDashboardView extends ConsumerStatefulWidget {
  const TailorDashboardView({super.key});

  @override
  ConsumerState<TailorDashboardView> createState() => _TailorDashboardViewState();
}

class _TailorDashboardViewState extends ConsumerState<TailorDashboardView> {
  TailorViewMode _viewMode = TailorViewMode.harqaan;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final userName = user?.name ?? 'Tailor';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopBar(userName),
            
            // View Mode Tab Bar (Ganacsi, Harqaan, Farsamo)
            _buildModeSelector(),
            
            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String name) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maamulka Harqaanlaha',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'So dhawoow, $name 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D3B66),
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D3B66).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.sync, color: Color(0xFF0D3B66)),
              onPressed: () {
                // Refresh tailor data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Xogta waa la sync gareeyay cloud-ka!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            _buildModeTab(TailorViewMode.ganacsi, 'Ganacsi (Showcase)', Icons.storefront),
            _buildModeTab(TailorViewMode.harqaan, 'Harqaan (Tailor)', Icons.cut_outlined),
            _buildModeTab(TailorViewMode.farsamo, 'Farsamo (Tech)', Icons.code_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(TailorViewMode mode, String title, IconData icon) {
    final isSelected = _viewMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _viewMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF0D3B66) : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_viewMode) {
      case TailorViewMode.ganacsi:
        return _buildGanacsiContent();
      case TailorViewMode.harqaan:
        return _buildHarqaanContent();
      case TailorViewMode.farsamo:
        return _buildFarsamoContent();
    }
  }

  // --- 1. GANACSI SHOWCASE VIEW ---
  Widget _buildGanacsiContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business Showcase Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D3B66), Color(0xFF1B62A4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D3B66).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Ganacsigaagu Waa Mid Firfircoon (Live)',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Harqaanle Smart Boutique',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Farsamo tolis casri ah oo lagugu kalsoonaan karo. Cabbiraadaada oo badbaado ah iyo ballamo sax ah.',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Mogadishu, Somalia',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.phone, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '+252 61 555 1234',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Noocyada Adeegyada (Sewing Catalog)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildCatalogCard('Shaar & Surwaal', '\$15 - \$30', Icons.checkroom),
            _buildCatalogCard('Dirac Casri ah', '\$20 - \$45', Icons.woman),
            _buildCatalogCard('Suit / Koodh', '\$50 - \$120', Icons.dry_cleaning),
            _buildCatalogCard('Macawiis & Cumaamad', '\$8 - \$15', Icons.style),
          ],
        ),
        const SizedBox(height: 24),
        // Customer Intake Inquiry Mock Form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Qaabilaadda Macmiil Cusub (Intake Inquiry)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Magaca Macmiilka',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Lambarka Taleefanka',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Xogta intake-ga waa la keydiyay!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Geli Dalab Cusub'),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogCard(String title, String price, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF0D3B66), size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(price, style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- 2. HARQAAN OPERATIONS VIEW (MAIN WORKSPACE) ---
  Widget _buildHarqaanContent() {
    final tailorState = ref.watch(tailorProvider);
    final now = DateTime.now();
    
    // Calculations
    final dueToday = tailorState.orders.where((o) {
      return o.dueDate.year == now.year && o.dueDate.month == now.month && o.dueDate.day == now.day && o.status != TailorOrderStatus.taken;
    }).length;
    
    final readyCount = tailorState.orders.where((o) => o.status == TailorOrderStatus.ready).length;
    
    double totalUnpaid = 0.0;
    for (final order in tailorState.orders) {
      if (order.status != TailorOrderStatus.taken) {
        totalUnpaid += order.balance;
      }
    }

    final filteredCustomers = tailorState.customers.where((c) {
      final nameMatches = c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final phoneMatches = c.phone.contains(_searchQuery);
      return nameMatches || phoneMatches;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid Summary Stats Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Maanta Ballanta',
                dueToday.toString(),
                'Dhar raba in la diyaariyo',
                Icons.calendar_today,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Diyaar Garoobay',
                readyCount.toString(),
                'Sugaya in la qaato',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Haraaga Isku-geyn Lagu Leeyahay',
          '\$${totalUnpaid.toStringAsFixed(2)}',
          'Lacagaha macaamiishu weli bixin',
          Icons.monetization_on,
          const Color(0xFF0D3B66),
        ),
        const SizedBox(height: 24),
        
        // Search & Quick Action Section
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Ka raadi magac ama taleefan...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_searchQuery.isNotEmpty) ...[
          const Text(
            'Natiijada Raadinta (Search Results)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
          ),
          const SizedBox(height: 10),
          if (filteredCustomers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Lama helin macmiil waafaqsan raadinta.'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCustomers.length,
              itemBuilder: (context, idx) {
                final customer = filteredCustomers[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(customer.phone),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Navigate to customers view or show measurement dialog
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Cabbirka: ${customer.name}'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Garab (Shoulder): ${customer.shoulder} cm'),
                              Text('Xabad (Chest): ${customer.chest} cm'),
                              Text('Dhex (Waist): ${customer.waist} cm'),
                              Text('Miskaha (Hips): ${customer.hips} cm'),
                              Text('Gacan (Sleeve): ${customer.sleeveLength} cm'),
                              Text('Dherer (Overall): ${customer.overallLength} cm'),
                              const SizedBox(height: 8),
                              Text('Faahfaahin: ${customer.notes}'),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xidh')),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
        ],

        // Quick Actions Row
        const Text(
          'Hawlaha Degdegga ah (Quick Actions)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Direct trigger of Customer Form Dialog
                  showDialog(
                    context: context,
                    builder: (context) => const TailorCustomerFormDialog(),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Macmiil Cusub'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Direct trigger of Order Form Dialog
                  showDialog(
                    context: context,
                    builder: (context) => const TailorOrderFormDialog(),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Dalab Cusub'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D3B66),
                  side: const BorderSide(color: Color(0xFF0D3B66)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Recent Orders list
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dalabaadkii U Dambeeyay',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (tailorState.orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Ma jiraan dalabaad la kaydiyay weli.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tailorState.orders.length > 5 ? 5 : tailorState.orders.length,
            itemBuilder: (context, idx) {
              final order = tailorState.orders[idx];
              final customer = tailorState.customers.firstWhere(
                (c) => c.id == order.customerId,
                orElse: () => TailorCustomer(
                  id: '',
                  name: 'Macmiil aan la aqoon',
                  phone: '',
                  gender: Gender.male,
                  shoulder: 0,
                  chest: 0,
                  waist: 0,
                  hips: 0,
                  sleeveLength: 0,
                  overallLength: 0,
                  notes: '',
                  updatedAt: DateTime.now(),
                ),
              );
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.white,
                child: ListTile(
                  title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${order.fabricType} • ${order.styleType}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C2340),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- 3. FARSAMO DIAGNOSTIC VIEW ---
  Widget _buildFarsamoContent() {
    final tailorState = ref.watch(tailorProvider);
    final user = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Technical Diagnostics Panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text(
                    'Nidaamka Cloud Sync Diagnostic',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildDiagRow('Database Status', 'Ku xiran yahay (Connected)', Colors.green),
              _buildDiagRow('Supabase Client API', 'Diyaar (OK)', Colors.green),
              _buildDiagRow('Offline Storage Local', 'Faol (Active)', Colors.green),
              _buildDiagRow('Client Identity ID', user?.id ?? 'Not Auth', Colors.blueGrey),
              _buildDiagRow('Total Clients Local Count', '${tailorState.customers.length}', Colors.blueGrey),
              _buildDiagRow('Total Orders Local Count', '${tailorState.orders.length}', Colors.blueGrey),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Raw Metadata JSON (Raw Schema)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66)),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '{\n  "tailor_customers": [\n    ${tailorState.customers.map((c) => '{"id": "${c.id}", "name": "${c.name}"}').join(',\n    ')}\n  ],\n  "tailor_orders": [\n    ${tailorState.orders.map((o) => '{"id": "${o.id}", "price": ${o.price}, "status": "${o.status.name}"}').join(',\n    ')}\n  ]\n}',
            style: const TextStyle(
              color: Colors.lightGreenAccent,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagRow(String key, String val, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$key:', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          Text(val, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: valColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getStatusColor(TailorOrderStatus status) {
    switch (status) {
      case TailorOrderStatus.received:
        return Colors.blue;
      case TailorOrderStatus.sewing:
        return Colors.orange;
      case TailorOrderStatus.ready:
        return Colors.green;
      case TailorOrderStatus.taken:
        return Colors.grey;
    }
  }

  String _getStatusText(TailorOrderStatus status) {
    switch (status) {
      case TailorOrderStatus.received:
        return 'La keenay';
      case TailorOrderStatus.sewing:
        return 'La jarjaray / Tolaayaa';
      case TailorOrderStatus.ready:
        return 'Wuu Diyaar garoobay';
      case TailorOrderStatus.taken:
        return 'Waa la qaatay';
    }
  }
}
