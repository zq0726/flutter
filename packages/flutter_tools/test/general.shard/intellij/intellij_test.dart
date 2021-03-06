// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/intellij/intellij.dart';

import '../../src/common.dart';

void main() {
  FileSystem fileSystem;

  void writeFileCreatingDirectories(String path, List<int> bytes) {
    final File file = fileSystem.file(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }

  setUp(() {
    fileSystem = MemoryFileSystem.test();
  });

  testWithoutContext('IntelliJPlugins found', () async {
    final IntelliJPlugins plugins = IntelliJPlugins(_kPluginsPath, fileSystem: fileSystem);

    final Archive dartJarArchive =
        buildSingleFileArchive('META-INF/plugin.xml', r'''
<idea-plugin version="2">
<name>Dart</name>
<version>162.2485</version>
</idea-plugin>
''');
    writeFileCreatingDirectories(
      fileSystem.path.join(_kPluginsPath, 'Dart', 'lib', 'Dart.jar'),
      ZipEncoder().encode(dartJarArchive),
    );

    final Archive flutterJarArchive = buildSingleFileArchive('META-INF/plugin.xml', r'''
<idea-plugin version="2">
<name>Flutter</name>
<version>0.1.3</version>
</idea-plugin>
''');
    writeFileCreatingDirectories(
      fileSystem.path.join(_kPluginsPath, 'flutter-intellij.jar'),
      ZipEncoder().encode(flutterJarArchive),
    );

    final List<ValidationMessage> messages = <ValidationMessage>[];
    plugins.validatePackage(messages, <String>['Dart'], 'Dart', 'download-Dart');
    plugins.validatePackage(messages,
      <String>['flutter-intellij', 'flutter-intellij.jar'], 'Flutter', 'download-Flutter',
      minVersion: IntelliJPlugins.kMinFlutterPluginVersion,
    );

    ValidationMessage message = messages
        .firstWhere((ValidationMessage m) => m.message.startsWith('Dart '));
    expect(message.message, 'Dart plugin version 162.2485');

    message = messages.firstWhere(
        (ValidationMessage m) => m.message.startsWith('Flutter '));
    expect(message.message, contains('Flutter plugin version 0.1.3'));
    expect(message.message, contains('recommended minimum version'));
  });

  testWithoutContext('IntelliJPlugins not found displays a link to their download site', () async {
    final IntelliJPlugins plugins = IntelliJPlugins(_kPluginsPath, fileSystem: fileSystem);

    final List<ValidationMessage> messages = <ValidationMessage>[];
    plugins.validatePackage(messages, <String>['Dart'], 'Dart', 'download-Dart');
    plugins.validatePackage(messages,
      <String>['flutter-intellij', 'flutter-intellij.jar'], 'Flutter', 'download-Flutter',
      minVersion: IntelliJPlugins.kMinFlutterPluginVersion,
    );

    ValidationMessage message = messages
        .firstWhere((ValidationMessage m) => m.message.startsWith('Dart '));
    expect(message.message, contains('Dart plugin can be installed from'));
    expect(message.contextUrl, isNotNull);

    message = messages.firstWhere(
        (ValidationMessage m) => m.message.startsWith('Flutter '));
    expect(message.message, contains('Flutter plugin can be installed from'));
    expect(message.contextUrl, isNotNull);
  });

  testWithoutContext('IntelliJPlugins does not crash if no plugin file found', () async {
    final IntelliJPlugins plugins = IntelliJPlugins(_kPluginsPath, fileSystem: fileSystem);

    final Archive dartJarArchive =
    buildSingleFileArchive('META-INF/plugin.xml', r'''
<idea-plugin version="2">
<name>Dart</name>
<version>162.2485</version>
</idea-plugin>
''');
    writeFileCreatingDirectories(
      fileSystem.path.join(_kPluginsPath, 'Dart', 'lib', 'Other.jar'),
      ZipEncoder().encode(dartJarArchive),
    );

    expect(
      () => plugins.validatePackage(<ValidationMessage>[], <String>['Dart'], 'Dart', 'download-Dart'),
      returnsNormally,
    );
  });
}

const String _kPluginsPath = '/data/intellij/plugins';

Archive buildSingleFileArchive(String path, String content) {
  final Archive archive = Archive();

  final List<int> bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(path, bytes.length, bytes));

  return archive;
}
