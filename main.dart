import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const HafizBiryaniPOSApp());
}

class HafizBiryaniPOSApp extends StatelessWidget {
  const HafizBiryaniPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hafiz Chicken Tikka Biryani POS',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Roboto',
      ),
      home: const BillingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final List<OrderItem> _orderItems = [];
  double _deliveryCharge = 0.0;
  String _orderType = 'Dine-in';
  String _paymentMethod = 'Cash';
  int _billNumber = 1;
  
  final List<String> _orderTypes = ['Dine-in', 'Takeaway', 'Delivery'];
  final List<String> _paymentMethods = ['Cash', 'JazzCash', 'Easypaisa', 'Other'];
  
  final List<MenuItem> _menuItems = [
    MenuItem(name: 'Chicken Tikka Biryani', price: 480.0, unit: 'kg'),
    MenuItem(name: 'Raita', price: 60.0, unit: 'unit'),
    MenuItem(name: 'Salad', price: 60.0, unit: 'unit'),
  ];

  Database? _database;

  @override
  void initState() {
    super.initState();
    _initDatabase();
    _loadBillNumber();
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'hafiz_biryani_pos.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bill_number INTEGER,
            date TEXT,
            order_type TEXT,
            payment_method TEXT,
            delivery_charge REAL,
            total_amount REAL
          )
        ''');
        
        await db.execute('''
          CREATE TABLE order_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bill_id INTEGER,
            name TEXT,
            price REAL,
            unit TEXT,
            quantity REAL,
            total REAL,
            FOREIGN KEY(bill_id) REFERENCES bills(id)
          )
        ''');
        
        await db.execute('''
          CREATE TABLE menu_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            price REAL,
            unit TEXT
          )
        ''');
        
        // Insert default menu items
        for (var item in _menuItems) {
          await db.insert('menu_items', {
            'name': item.name,
            'price': item.price,
            'unit': item.unit,
          });
        }
      },
    );
  }

  void _loadBillNumber() async {
    // In a real app, load from database based on current date
    setState(() {
      _billNumber = 42; // Example bill number
    });
  }

  void _addNewItem() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddItemDialog(
          menuItems: _menuItems,
          onItemAdded: (OrderItem newItem) {
            setState(() {
              _orderItems.add(newItem);
            });
          },
        );
      },
    );
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddItemDialog(
          menuItems: _menuItems,
          existingItem: _orderItems[index],
          onItemAdded: (OrderItem updatedItem) {
            setState(() {
              _orderItems[index] = updatedItem;
            });
          },
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  double get _subTotal {
    return _orderItems.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _total {
    return _subTotal + _deliveryCharge;
  }

  void _saveBill() async {
    if (_database == null) return;
    
    final billId = await _database!.insert('bills', {
      'bill_number': _billNumber,
      'date': DateTime.now().toIso8601String(),
      'order_type': _orderType,
      'payment_method': _paymentMethod,
      'delivery_charge': _deliveryCharge,
      'total_amount': _total,
    });
    
    for (var item in _orderItems) {
      await _database!.insert('order_items', {
        'bill_id': billId,
        'name': item.name,
        'price': item.price,
        'unit': item.unit,
        'quantity': item.quantity,
        'total': item.total,
      });
    }
    
    _showReceipt(context, false);
  }

  void _saveAndShare() async {
    await _saveBill();
    _showReceipt(context, true);
  }

  void _printBill() {
    _showReceipt(context, false);
  }

  void _newBill() {
    setState(() {
      _orderItems.clear();
      _deliveryCharge = 0.0;
      _loadBillNumber();
    });
  }

  void _showReceipt(BuildContext context, bool forSharing) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReceiptDialog(
          orderItems: _orderItems,
          deliveryCharge: _deliveryCharge,
          orderType: _orderType,
          paymentMethod: _paymentMethod,
          billNumber: _billNumber,
          forSharing: forSharing,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hafiz Chicken Tikka Biryani POS'),
        backgroundColor: Colors.orange[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt),
            onPressed: () {
              // Navigate to bills list
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              // Navigate to reports
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with date and bill info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Bill #: $_billNumber',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Order type and payment method selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _orderType,
                    items: _orderTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _orderType = newValue!;
                        if (_orderType != 'Delivery') {
                          _deliveryCharge = 0.0;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Order Type',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    items: _paymentMethods.map((String method) {
                      return DropdownMenuItem<String>(
                        value: method,
                        child: Text(method),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _paymentMethod = newValue!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Delivery charges input (visible only for delivery)
          if (_orderType == 'Delivery')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Text('Delivery Charges:'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      initialValue: _deliveryCharge.toStringAsFixed(0),
                      onChanged: (value) {
                        setState(() {
                          _deliveryCharge = double.tryParse(value) ?? 0.0;
                        });
                      },
                      decoration: const InputDecoration(
                        prefixText: 'Rs. ',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Order items table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.orange[50],
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Price/Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 40, child: Icon(Icons.edit, size: 16)),
              ],
            ),
          ),
          
          // Order items list
          Expanded(
            child: ListView.builder(
              itemCount: _orderItems.length,
              itemBuilder: (context, index) {
                final item = _orderItems[index];
                return Container(
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.grey[50] : Colors.white,
                    border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 40, child: Text('${index + 1}')),
                        Expanded(flex: 3, child: Text(item.name)),
                        Expanded(
                          flex: 2,
                          child: Text('Rs. ${item.price.toStringAsFixed(0)}/${item.unit}'),
                        ),
                        Expanded(flex: 2, child: Text('${item.quantity}')),
                        Expanded(
                          flex: 2,
                          child: Text('Rs. ${item.total.toStringAsFixed(0)}'),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () => _editItem(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Total section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('Rs. ${_subTotal.toStringAsFixed(0)}'),
                  ],
                ),
                if (_deliveryCharge > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Charges:'),
                      Text('Rs. ${_deliveryCharge.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Rs. ${_total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[300],
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    onPressed: _addNewItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt),
                    label: const Text('Save'),
                    onPressed: _saveBill,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    onPressed: _printBill,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.whatsapp),
                    label: const Text('WhatsApp'),
                    onPressed: _saveAndShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
}

class MenuItem {
  final String name;
  final double price;
  final String unit;

  MenuItem({required this.name, required this.price, required this.unit});
}

class OrderItem {
  final String name;
  final double price;
  final String unit;
  final double quantity;

  OrderItem({
    required this.name,
    required this.price,
    required this.unit,
    required this.quantity,
  });

  double get total => price * quantity;
}

class AddItemDialog extends StatefulWidget {
  final List<MenuItem> menuItems;
  final OrderItem? existingItem;
  final Function(OrderItem) onItemAdded;

  const AddItemDialog({
    super.key,
    required this.menuItems,
    this.existingItem,
    required this.onItemAdded,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedItem = '';
  String _customItemName = '';
  double _price = 0.0;
  double _quantity = 1.0;
  String _unit = 'kg';
  bool _isCustomItem = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _isCustomItem = !widget.menuItems.any((item) => item.name == widget.existingItem!.name);
      if (_isCustomItem) {
        _customItemName = widget.existingItem!.name;
      } else {
        _selectedItem = widget.existingItem!.name;
      }
      _price = widget.existingItem!.price;
      _quantity = widget.existingItem!.quantity;
      _unit = widget.existingItem!.unit;
    } else if (widget.menuItems.isNotEmpty) {
      _selectedItem = widget.menuItems.first.name;
      _price = widget.menuItems.first.price;
      _unit = widget.menuItems.first.unit;
    }
  }

  void _updatePrice() {
    if (!_isCustomItem && _selectedItem.isNotEmpty) {
      final selected = widget.menuItems.firstWhere((item) => item.name == _selectedItem);
      setState(() {
        _price = selected.price;
        _unit = selected.unit;
      });
    }
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      final itemName = _isCustomItem ? _customItemName : _selectedItem;
      final newItem = OrderItem(
        name: itemName,
        price: _price,
        unit: _unit,
        quantity: _quantity,
      );
      widget.onItemAdded(newItem);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existingItem != null ? 'Edit Item' : 'Add New Item',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Toggle between menu item and custom item
              Row(
                children: [
                  const Text('Item Type:'),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('Menu Item'),
                    selected: !_isCustomItem,
                    onSelected: (selected) {
                      setState(() {
                        _isCustomItem = !selected;
                        if (!_isCustomItem && widget.menuItems.isNotEmpty) {
                          _selectedItem = widget.menuItems.first.name;
                          _updatePrice();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Custom Item'),
                    selected: _isCustomItem,
                    onSelected: (selected) {
                      setState(() {
                        _isCustomItem = selected;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Item selection or custom name input
              if (!_isCustomItem)
                DropdownButtonFormField<String>(
                  value: _selectedItem,
                  items: widget.menuItems.map((MenuItem item) {
                    return DropdownMenuItem<String>(
                      value: item.name,
                      child: Text(item.name),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedItem = newValue!;
                      _updatePrice();
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Select Item',
                  ),
                )
              else
                TextFormField(
                  initialValue: _customItemName,
                  onChanged: (value) => _customItemName = value,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an item name';
                    }
                    return null;
                  },
                ),
              
              const SizedBox(height: 16),
              
              // Unit selection
              DropdownButtonFormField<String>(
                value: _unit,
                items: ['kg', 'unit', 'pack'].map((String unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _unit = newValue!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Unit',
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Price input
              TextFormField(
                keyboardType: TextInputType.number,
                initialValue: _price.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() {
                    _price = double.tryParse(value) ?? 0.0;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: 'Rs. ',
                ),
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Quantity input
              TextFormField(
                keyboardType: TextInputType.number,
                initialValue: _quantity.toString(),
                onChanged: (value) {
                  setState(() {
                    _quantity = double.tryParse(value) ?? 0.0;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  suffixText: _unit,
                ),
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Total display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Rs. ${(_price * _quantity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Item'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReceiptDialog extends StatelessWidget {
  final List<OrderItem> orderItems;
  final double deliveryCharge;
  final String orderType;
  final String paymentMethod;
  final int billNumber;
  final bool forSharing;

  const ReceiptDialog({
    super.key,
    required this.orderItems,
    required this.deliveryCharge,
    required this.orderType,
    required this.paymentMethod,
    required this.billNumber,
    this.forSharing = false,
  });

  double get subtotal {
    return orderItems.fold(0.0, (sum, item) => sum + item.total);
  }

  double get total {
    return subtotal + deliveryCharge;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: forSharing ? 300 : double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Receipt header
            const Text(
              'HAFIZ CHICKEN TIKKA BIRYANI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Bill #: $billNumber',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now()),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Order Type: $orderType | Payment: $paymentMethod',
              style: const TextStyle(fontSize: 12),
            ),
            
            const Divider(),
            
            // Order items
            const Row(
              children: [
                Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            
            ...orderItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(item.name)),
                  Expanded(flex: 2, child: Text('${item.quantity} ${item.unit}')),
                  Expanded(flex: 2, child: Text('Rs. ${item.total.toStringAsFixed(0)}')),
                ],
              ),
            )),
            
            const Divider(),
            
            // Totals
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(flex: 3, child: Text('Subtotal')),
                  const Expanded(flex: 2, child: SizedBox()),
                  Expanded(flex: 2, child: Text('Rs. ${subtotal.toStringAsFixed(0)}')),
                ],
              ),
            ),
            
            if (deliveryCharge > 0) Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(flex: 3, child: Text('Delivery Charge')),
                  const Expanded(flex: 2, child: SizedBox()),
                  Expanded(flex: 2, child: Text('Rs. ${deliveryCharge.toStringAsFixed(0)}')),
                ],
              ),
            ),
            
            const Divider(),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(flex: 2, child: SizedBox()),
                  Expanded(flex: 2, child: Text('Rs. ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Thank you for your order!',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            
            const SizedBox(height: 16),
            
            if (forSharing)
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share via WhatsApp'),
                onPressed: () {
                  // Implement WhatsApp sharing functionality
                  final message = '''
HAFIZ CHICKEN TIKKA BIRYANI
Bill #: $billNumber
Date: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}
Order Type: $orderType
Payment: $paymentMethod

${orderItems.map((item) => '${item.name} - ${item.quantity} ${item.unit} - Rs. ${item.total.toStringAsFixed(0)}').join('\n')}

Subtotal: Rs. ${subtotal.toStringAsFixed(0)}
${deliveryCharge > 0 ? 'Delivery Charge: Rs. ${deliveryCharge.toStringAsFixed(0)}\n' : ''}
TOTAL: Rs. ${total.toStringAsFixed(0)}

Thank you for your order!
                  ''';
                  
                  Share.share(message);
                  Navigator.of(context).pop();
                },
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }
}
