class TransactionalFileTemplate {
  Iterable<String> storeSources;

  @override
  String toString() => storeSources.isEmpty
      ? ''
      : '''

        ${storeSources.join('\n\n')}
        ''';
}
