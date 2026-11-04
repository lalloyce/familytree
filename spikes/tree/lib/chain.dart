// The spoken chain: a plain list that reads "Kito, son of Rafa, house 2".
// Design section 7. Names wrap, never truncate.
import 'package:flutter/material.dart';

import 'gen.dart';

/// The spoken line for one person.
String chainText(Dataset d, int personId) {
  final p = d.people[personId];
  final fh = p.fatherHouse;
  if (fh == null) return '${p.name}, earliest we know of';
  final house = d.houses[fh];
  final father = d.people[house.husbandId];
  final b = StringBuffer(
      '${p.name}, ${p.isFemale ? 'daughter' : 'son'} of ${father.name}, '
      'house ${house.order}');
  final wives = d.wifeHouses[personId];
  if (wives.length > 1) {
    b.write('. Same person: ');
    for (var i = 0; i < wives.length; i++) {
      final h = d.houses[wives[i]];
      if (i > 0) b.write(' and ');
      b.write('wife of ${d.people[h.husbandId].name}, house ${h.order}');
    }
  }
  return b.toString();
}

const double kChainFont = 16;

/// One row of the chain. The text is never given a max line count and never
/// ellipsised, so a long name wraps onto as many lines as it needs.
class ChainLine extends StatelessWidget {
  const ChainLine({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFBDBDBD))),
        ),
        child: Text(
          text,
          softWrap: true,
          style: const TextStyle(fontSize: kChainFont, height: 1.3),
        ),
      ),
    );
  }
}

class ChainList extends StatelessWidget {
  const ChainList({
    super.key,
    required this.data,
    required this.controller,
    required this.onSelect,
  });

  final Dataset data;
  final ScrollController controller;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: data.people.length,
      itemBuilder: (context, i) => ChainLine(
        text: chainText(data, i),
        onTap: () => onSelect(i),
      ),
    );
  }
}
