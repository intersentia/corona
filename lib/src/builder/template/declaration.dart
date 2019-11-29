import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'package:corona/src/builder/template/helpers/naming.dart' as naming;
import 'package:corona/src/builder/template/helpers/tokens.dart' as tokens;

class DeclarationDecoder<S extends ClassElement, T extends String>
    extends Converter<S, T> {
  const DeclarationDecoder();

  @override
  T convert(S input) {
    final buffer = StringBuffer();
    final interfaces = <InterfaceType>[input.type];

    buffer.writeln('@immutable');
    buffer.write(tokens.decl.forClass);
    buffer.write(tokens.space);
    buffer.write(naming.getImplClassName(input.displayName));

    if (_hasGenericTypes(input)) {
      buffer.write(tokens.typeOpen);
      buffer.write(_getGenericTypeDecl(input).join(', '));
      buffer.write(tokens.typeClose);
    }

    if (!input.supertype.isObject || input.mixins.isNotEmpty) {
      if (input.supertype.element.isAbstract) {
        interfaces.add(input.supertype);

        buffer.write(tokens.space);
        buffer.write(tokens.decl.forExtends);
        buffer.write(tokens.space);
        buffer.write('Object');
      } else {
        buffer.write(tokens.space);
        buffer.write(tokens.decl.forExtends);
        buffer.write(tokens.space);
        buffer.write(input.supertype.displayName);
      }
    }

    if (input.mixins.isNotEmpty) {
      buffer.write(tokens.space);
      buffer.write(tokens.decl.forMixins);
      buffer.write(tokens.space);
      buffer.write(input.mixins
          .map((InterfaceType type) => type.displayName)
          .join(', '));
    }

    interfaces.addAll(input.interfaces);

    if (interfaces.isNotEmpty) {
      buffer.write(tokens.space);
      buffer.write(tokens.decl.forImplements);
      buffer.write(tokens.space);
      buffer.write(
          interfaces.map((InterfaceType type) => type.displayName).join(', '));
    }

    buffer.write(tokens.bracketsOpen);

    final accessors = Set<PropertyAccessorElement>();

    interfaces.map((type) => type.accessors).forEach(accessors.addAll);

    accessors.forEach((accessor) {
      buffer.write('@override ');
      buffer.write(tokens.decl.forFinal);
      buffer.write(tokens.space);
      buffer.write(accessor.returnType.displayName);
      buffer.write(tokens.space);
      buffer.write(accessor.displayName);
      buffer.write(tokens.closeLine);
    });

    buffer.write(tokens.ctrConst);
    buffer.write(tokens.space);
    buffer.write(naming.getImplClassName(input.displayName));
    buffer.write(tokens.argsOpen);

    if (accessors.isNotEmpty) {
      buffer.write(tokens.bracketsOpen);

      buffer.write(accessors
          .map((accessor) => 'this.${accessor.displayName}')
          .join(','));

      buffer.write(tokens.bracketsClose);
    }

    buffer.write(tokens.argsClose);
    buffer.write(tokens.closeLine);

    buffer.writeln('@override');
    buffer.write(tokens.space);
    buffer.write(tokens.decl.forDynamic);
    buffer.write(tokens.space);
    buffer.write('getValueFromKey');
    buffer.write(tokens.argsOpen);
    buffer.write('String key');
    buffer.write(tokens.argsClose);
    buffer.write(tokens.bracketsOpen);
    buffer.write('switch (key)');
    buffer.write(tokens.bracketsOpen);

    accessors.forEach((accessor) {
      buffer.write('case');
      buffer.write(tokens.space);
      buffer.write(
          ''' '${accessor.displayName}':return ${accessor.displayName} ''');
      buffer.write(tokens.closeLine);
    });

    buffer.write(tokens.bracketsClose);

    buffer.write(tokens.decl.forReturn);
    buffer.write(tokens.space);
    buffer.write('null');
    buffer.write(tokens.closeLine);
    buffer.write(tokens.bracketsClose);

    buffer.writeln('@override');
    buffer.write(tokens.space);
    buffer.write('List<TearOffAndValueObjectSchema>');
    buffer.write(tokens.space);
    buffer.write('expand');
    buffer.write(tokens.argsOpen);
    buffer.write('[List<TearOffAndValueObjectSchema> list]');
    buffer.write(tokens.argsClose);
    buffer.writeln(tokens.bracketsOpen);
    buffer.write('list ??= <TearOffAndValueObjectSchema>[]');
    buffer.writeln(tokens.closeLine);
    buffer.write('list.add(this)');
    buffer.writeln(tokens.closeLine);

    accessors
        .where((accessor) => accessor.returnType.element is ClassElement)
        .forEach((accessor) {
      final ClassElement elmCast = accessor.returnType.element;
      final tearoffType = elmCast.allSupertypes.firstWhere(
          (type) => type.displayName == 'TearOffAndValueObjectSchema',
          orElse: () => null);
      final iterableType = elmCast.allSupertypes.firstWhere(
          (type) => type.element.library.isDartCore && type.name == 'Iterable',
          orElse: () => null);

      if (tearoffType != null) {
        buffer.write('if (${accessor.displayName} != null)');
        buffer.write(tokens.bracketsOpen);
        buffer.writeln('this.${accessor.displayName}.expand(list)');
        buffer.writeln(tokens.closeLine);
        buffer.write(tokens.bracketsClose);
      } else if (iterableType != null) {
        final type = accessor.returnType;

        if (type is InterfaceType) {
          if (![
            'int',
            'double',
            'num',
            'String',
            'bool',
            'Map<String, dynamic>',
            'Map'
          ].contains(type.typeArguments.first.displayName)) {
            buffer.writeln(
                'this.${accessor.displayName}?.forEach((${type.typeArguments.first.displayName} item) => item.expand(list))');
            buffer.writeln(tokens.closeLine);
          }
        }
      }
    });

    buffer.writeln(tokens.decl.forReturn);
    buffer.writeln(tokens.space);
    buffer.writeln('list');
    buffer.writeln(tokens.closeLine);

    buffer.write(tokens.bracketsClose);

    buffer.writeln('@override');
    buffer.write(tokens.space);
    buffer.write('bool');
    buffer.write(tokens.space);
    buffer.write('operator');
    buffer.write(tokens.space);
    buffer.write('==');
    buffer.write(tokens.argsOpen);
    buffer.write('Object other');
    buffer.write(tokens.argsClose);
    buffer.write(tokens.space);
    buffer.writeln(tokens.fatArrow);

    buffer.writeln(
        'other is ${input.displayName} && other.hashCode == this.hashCode');

    buffer.write(tokens.closeLine);

    /*
    @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Notification &&
        this.kind == other.kind &&
        this.error == other.error &&
        this.stackTrace == other.stackTrace &&
        this.value == other.value;
  }
     */

    buffer.writeln('@override');
    buffer.write(tokens.space);
    buffer.write('int');
    buffer.write(tokens.space);
    buffer.write('get');
    buffer.write(tokens.space);
    buffer.write('hashCode');
    buffer.write(tokens.fatArrow);

    String stepper = '0';

    accessors
        .where((accessor) => accessor.returnType.element is ClassElement)
        .forEach((PropertyAccessorElement accessor) {
      final ClassElement elmCast = accessor.returnType.element;
      String current;

      /// _finish(_combine(_combine(0, a.hashCode), b.hashCode));
      final InterfaceType iterableType = elmCast.allSupertypes.firstWhere(
          (type) => type.element.library.isDartCore && type.name == 'Iterable',
          orElse: () => null);

      if (iterableType != null) {
        current = 'hash_combineAll(this.${accessor.displayName})';
      } else {
        if (accessor.returnType.displayName == 'double')
          current =
              'this.${accessor.displayName} == null ? null.hashCode : this.${accessor.displayName}.toString().hashCode';
        else
          current = 'this.${accessor.displayName}.hashCode';
      }

      stepper = 'hash_combine($stepper, $current)';
    });

    buffer.writeln('hash_finish($stepper)');
    buffer.writeln(tokens.closeLine);

    buffer.writeln('@override');
    buffer.write(tokens.space);
    buffer.write('Map<String, dynamic>');
    buffer.write(tokens.space);
    buffer.write('toJSON');
    buffer.write(tokens.argsOpen);
    buffer.write(tokens.argsClose);
    buffer.write(tokens.fatArrow);
    buffer.write(tokens.ctrConst);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecEncoderName(input.displayName));
    buffer.write(tokens.argsOpen);
    buffer.write(tokens.argsClose);
    buffer.write('.convert');
    buffer.write(tokens.argsOpen);
    buffer.write('this');
    buffer.write(tokens.argsClose);
    buffer.write(tokens.closeLine);

    buffer.write('@override');
    buffer.write(tokens.space);
    buffer.write('Function(dynamic, String, dynamic)');
    buffer.write(tokens.space);
    buffer.write('getTearOffForKey');
    buffer.write(tokens.argsOpen);
    buffer.write('String key');
    buffer.write(tokens.argsClose);
    buffer.write(tokens.bracketsOpen);
    buffer.write('switch (key)');
    buffer.write(tokens.bracketsOpen);

    accessors.forEach((accessor) {
      if (accessor.isGetter) {
        buffer.write('''case '${accessor.displayName}': ''');

        if (accessor.returnType.element.kind.ordinal > 0) {
          buffer.write(tokens.decl.forReturn);
          buffer.write(tokens.space);
          buffer.write('null');
          buffer.write(tokens.closeLine);
        } else if (accessor.returnType.element.library.displayName ==
            input.library.displayName) {
          buffer.write(tokens.decl.forReturn);
          buffer.write(tokens.space);
          buffer
              .write(naming.getCtrTearOffName(accessor.returnType.displayName));
          buffer.write(tokens.space);
          buffer.write('as Function(dynamic, String, dynamic)');
          buffer.write(tokens.closeLine);
        } else {
          buffer.write(tokens.decl.forReturn);
          buffer.write(tokens.space);
          buffer.write('null');
          buffer.write(tokens.closeLine);
        }
      }
    });

    buffer.write(tokens.bracketsClose);

    buffer.write(tokens.decl.forReturn);
    buffer.write(tokens.space);
    buffer.write('null');
    buffer.write(tokens.closeLine);

    buffer.write(tokens.bracketsClose);

    buffer.write(tokens.bracketsClose);

    ///

    buffer.write(tokens.decl.forClass);
    buffer.write(tokens.space);
    buffer.write(naming.getFactoryName(input.displayName));

    buffer.write(tokens.bracketsOpen);

    buffer.write(tokens.decl.forStatic);
    buffer.write(tokens.space);
    buffer.write(input.displayName);

    if (_hasGenericTypes(input)) {
      buffer.write(tokens.typeOpen);
      buffer.write(
          _getGenericTypeDecl(input).map((decl) => decl.name).join(', '));
      buffer.write(tokens.typeClose);
    }

    buffer.write(tokens.space);
    buffer.write('create');

    if (_hasGenericTypes(input)) {
      buffer.write(tokens.typeOpen);
      buffer.write(_getGenericTypeDecl(input).join(', '));
      buffer.write(tokens.typeClose);
    }

    buffer.write(tokens.argsOpen);

    if (accessors.isNotEmpty) {
      buffer.write(tokens.bracketsOpen);

      buffer.write(accessors
          .map((accessor) =>
              '${accessor.returnType.displayName} ${accessor.displayName}')
          .join(','));

      buffer.write(tokens.bracketsClose);
    }

    buffer.write(tokens.argsClose);

    buffer.write(tokens.fatArrow);
    buffer.write(tokens.ctrNew);
    buffer.write(tokens.space);
    buffer.write(naming.getImplClassName(input.displayName));

    if (_hasGenericTypes(input)) {
      buffer.write(tokens.typeOpen);
      buffer.write(
          _getGenericTypeDecl(input).map((decl) => decl.name).join(', '));
      buffer.write(tokens.typeClose);
    }

    buffer.write(tokens.argsOpen);

    if (accessors.isNotEmpty) {
      buffer.write(accessors
          .map((accessor) => '${accessor.displayName}:${accessor.displayName}')
          .join(','));
    }

    buffer.write(tokens.argsClose);
    buffer.write(tokens.closeLine);

    buffer.write(tokens.bracketsClose);

    /// Codec
    buffer.write(tokens.decl.forClass);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecName(input.displayName));
    buffer.write(tokens.space);

    buffer.write('extends Codec<${input.displayName}, Map>');

    buffer.writeln(tokens.bracketsOpen);

    /*
    const QuestionCodec();

  @override
  Converter<Question, Map<String, dynamic>> get encoder =>
      const QuestionEncoder<Question, Map<String, dynamic>>();
  @override
  Converter<Map<String, dynamic>, Question> get decoder =>
      const QuestionDecoder<Map<String, dynamic>, Question>();
     */

    buffer.write(tokens.ctrConst);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecName(input.displayName));
    buffer.write(tokens.argsOpen);
    buffer.write(tokens.argsClose);
    buffer.writeln(tokens.closeLine);

    buffer.writeln('@override');
    buffer.writeln('Converter<${input.displayName}, Map> get encoder');
    buffer.write(tokens.space);
    buffer.write(tokens.fatArrow);
    buffer.write(tokens.space);
    buffer.write(tokens.ctrConst);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecEncoderName(input.displayName));
    buffer.write(tokens.argsOpen);
    buffer.write(tokens.argsClose);
    buffer.writeln(tokens.closeLine);

    buffer.writeln('@override');
    buffer.writeln('Converter<Map, ${input.displayName}> get decoder');
    buffer.write(tokens.space);
    buffer.write(tokens.fatArrow);
    buffer.write(tokens.space);
    buffer.write(tokens.ctrConst);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecDecoderName(input.displayName));
    buffer.write(tokens.argsOpen);
    buffer.write(tokens.argsClose);
    buffer.writeln(tokens.closeLine);

    buffer.write(tokens.bracketsClose);

    /*
    class QuestionEncoder
    extends Converter<Question, Map<String, dynamic>> {
  const QuestionEncoder();

  @override
  Map<String, dynamic> convert(Question data) {
    if (data == null) return null;

    final AnswerCodec answerCodec = const AnswerCodec();

    return <String, dynamic>{
      ModuleEntity.ID: data.id,
      Question.TYPE: data.type,
      Question.QUESTION: data.question,
      Question.ANSWERS: data.answers?.map(answerCodec.encode)?.toList()
    };
  }
}
     */

    buffer.write(tokens.decl.forClass);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecEncoderName(input.displayName));
    buffer.write(tokens.space);

    buffer.write('extends Converter<${input.displayName}, Map>');

    buffer.writeln(tokens.bracketsOpen);

    buffer.write(tokens.ctrConst);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecEncoderName(input.displayName));
    buffer.write(tokens.argsOpen);
    buffer.write(tokens.argsClose);
    buffer.writeln(tokens.closeLine);

    buffer.writeln('@override');
    buffer.write('Map');
    buffer.write(tokens.space);
    buffer.write('convert');
    buffer.write(tokens.argsOpen);
    buffer.write('${input.displayName} data');
    buffer.write(tokens.argsClose);

    buffer.write(tokens.fatArrow);
    buffer.write(tokens.space);
    buffer.write('<String, dynamic>');
    buffer.writeln(tokens.bracketsOpen);

    if (accessors.isNotEmpty) {
      accessors.forEach((accessor) {
        buffer.writeln(
            ''' '${accessor.displayName}': ${_toMapValueForCodec(accessor.displayName, accessor.returnType.displayName, accessor.returnType)},''');
      });
    }

    buffer.writeln(tokens.bracketsClose);

    buffer.write(tokens.closeLine);

    buffer.writeln(tokens.bracketsClose);

    buffer.write(tokens.decl.forClass);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecDecoderName(input.displayName));
    buffer.write(tokens.space);

    buffer.write('extends Converter<Map, ${input.displayName}>');

    buffer.writeln(tokens.bracketsOpen);

    buffer.write(tokens.ctrConst);
    buffer.write(tokens.space);
    buffer.write(naming.getCodecDecoderName(input.displayName));
    buffer.write(tokens.argsOpen);
    buffer.write(tokens.argsClose);
    buffer.writeln(tokens.closeLine);

    buffer.writeln('@override');
    buffer.write(input.displayName);
    buffer.write(tokens.space);
    buffer.write('convert');
    buffer.write(tokens.argsOpen);
    buffer.write('Map data');
    buffer.write(tokens.argsClose);

    buffer.write(tokens.fatArrow);
    buffer.write(tokens.space);

    buffer.write(naming.getFactoryName(input.displayName));
    buffer.write('.create');
    buffer.writeln(tokens.argsOpen);

    if (accessors.isNotEmpty) {
      accessors.forEach((accessor) {
        buffer.writeln(
            ''' ${accessor.displayName}: ${_toPropertyForCodec(accessor.displayName, accessor.returnType.displayName, accessor.returnType)},''');
      });
    }

    buffer.writeln(tokens.argsClose);

    buffer.write(tokens.closeLine);

    buffer.writeln(tokens.bracketsClose);

    /// end Codec

    return buffer.toString();
  }

  String _toMapValueForCodec(String property, String displayName, DartType type,
      {bool asTearoff: false}) {
    switch (displayName) {
      case 'int':
      case 'num':
      case 'double':
      case 'String':
      case 'bool':
        return 'data?.$property';
      case 'DateTime':
        return 'data?.$property?.millisecondsSinceEpoch';
      default:
        final elm = type.element;

        if (elm is ClassElement) {
          final iterableType = elm.allSupertypes.firstWhere(
              (type) =>
                  type.element.library.isDartCore && type.name == 'Iterable',
              orElse: () => null);

          if (iterableType != null) {
            final InterfaceType interfaceType = type;

            if ([
              'int',
              'double',
              'num',
              'String',
              'bool',
              'Map<String, dynamic>',
              'Map'
            ].contains(interfaceType.typeArguments.first.displayName)) {
              return 'data?.$property';
            }

            final codec = _toMapValueForCodec(
                property,
                interfaceType.typeArguments.first.displayName,
                interfaceType.typeArguments.first,
                asTearoff: true);

            return 'data?.$property?.map($codec)?.toList(growable: false)';
          } else {
            if (asTearoff) {
              return 'const ${type.name}Encoder().convert';
            }

            return 'data == null || data.$property == null ? null : const ${type.name}Encoder().convert(data.$property)';
          }
        }

        break;
    }

    return null;
  }

  String _toPropertyForCodec(String property, String displayName, DartType type,
      {bool asTearoff: false}) {
    switch (displayName) {
      case 'int':
      case 'num':
      case 'double':
      case 'String':
      case 'bool':
        return '''data['$property'] as $displayName''';
      case 'DateTime':
        return '''data == null || data['$property'] == null ? null : new DateTime.fromMillisecondsSinceEpoch(data['$property'] as int)''';
      default:
        final elm = type.element;

        if (elm is ClassElement) {
          final iterableType = elm.allSupertypes.firstWhere(
              (type) =>
                  type.element.library.isDartCore && type.name == 'Iterable',
              orElse: () => null);

          if (iterableType != null) {
            if (type is InterfaceType) {
              if ([
                'int',
                'double',
                'num',
                'String',
                'bool',
                'Map<String, dynamic>',
                'Map'
              ].contains(type.typeArguments.first.displayName)) {
                return '''data['$property']?.cast<${type.typeArguments.first.displayName}>()''';
              }

              final String codec = _toPropertyForCodec(
                  property,
                  type.typeArguments.first.displayName,
                  type.typeArguments.first,
                  asTearoff: true);

              return '''(data['$property'] as List)?.cast<Map>()?.map($codec)?.toList(growable: false)''';
            }
          } else {
            if (asTearoff) {
              return '''const ${type.name}Decoder().convert''';
            }

            return '''data == null || data['$property'] == null ? null : const ${type.name}Decoder().convert(data['$property'] as Map)''';
          }
        }

        break;
    }

    return null;
  }

  bool _hasGenericTypes(S input) => input.type.typeParameters.isNotEmpty;

  Iterable<_GenericTypeDecl> _getGenericTypeDecl(S input) {
    final list = <_GenericTypeDecl>[];

    input.type.typeParameters.forEach((t) {
      list.add(_GenericTypeDecl(t.displayName, t.bound.displayName));
    });

    return list;
  }
}

class _GenericTypeDecl {
  final String name, ext;

  _GenericTypeDecl(this.name, this.ext);

  String toString() => '$name extends $ext';
}
