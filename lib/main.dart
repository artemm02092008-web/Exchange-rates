import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';

// Модель для хранения данных о валюте
class CurrencyRate {
  final String code;
  final String name;
  final double value;
  final int nominal;

  CurrencyRate({
    required this.code,
    required this.name,
    required this.value,
    required this.nominal,
  });
}

// Функция для правильного чтения русских букв из Windows-1251
String decodeWindows1251(List<int> bytes) {
  return String.fromCharCodes(bytes.map((byte) {
    // Преобразуем байты Windows-1251 в Unicode
    if (byte >= 192 && byte <= 255) return byte + 848; // Русские буквы А-я
    if (byte == 168) return 1025; // Ё
    if (byte == 184) return 1105; // ё
    return byte; // Остальные символы (латиница, цифры) совпадают с ASCII
  }));
}

// Функция парсинга XML
List<CurrencyRate> parseCbrXml(String xmlString) {
  final doc = XmlDocument.parse(xmlString);
  final valutes = doc.findAllElements('Valute');
  final List<CurrencyRate> result = [];

  for (final valute in valutes) {
    final code = valute.findElements('CharCode').firstOrNull?.text ?? '';
    final name = valute.findElements('Name').firstOrNull?.text ?? 'Неизвестно';
    final nominalText = valute.findElements('Nominal').firstOrNull?.text ?? '1';
    final valueText = valute.findElements('Value').firstOrNull?.text ?? '0';

    final double value = double.tryParse(valueText.replaceAll(',', '.')) ?? 0.0;
    final int nominal = int.tryParse(nominalText) ?? 1;

    if (code.isNotEmpty) {
      result.add(CurrencyRate(
        code: code,
        name: name,
        value: value,
        nominal: nominal,
      ));
    }
  }
  return result;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CurrencyScreen(),
    );
  }
}

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  List<CurrencyRate> _rates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://www.cbr.ru/scripts/XML_daily.asp'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Статус: ${response.statusCode}');
      }

      // ИСПРАВЛЕНИЕ: Декодируем байты из Windows-1251 в читаемый текст
      final String xmlString = decodeWindows1251(response.bodyBytes);

      if (!xmlString.trim().startsWith('<?xml')) {
        throw Exception('Сервер вернул не XML. Возможно, сработала защита ЦБ.');
      }

      final rates = parseCbrXml(xmlString);

      setState(() {
        _rates = rates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Курсы валют ЦБ РФ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRates,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Ошибка: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRates,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rates.length,
      itemBuilder: (context, index) {
        final r = _rates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(child: Text(r.code)),
            title: Text(r.name),
            subtitle: Text('${r.nominal} ${r.code} = ${r.value.toStringAsFixed(2)} ₽'),
          ),
        );
      },
    );
  }
}