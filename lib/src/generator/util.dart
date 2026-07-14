// Analyzer 8 marks required replacement element APIs as experimental.
// ignore_for_file: experimental_member_use, public_member_api_docs

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:crimson/src/annotations.dart';
import 'package:source_gen/source_gen.dart';

const TypeChecker _jsonChecker = TypeChecker.typeNamed(Json);
const TypeChecker _jsonKebabChecker = TypeChecker.typeNamed(JsonKebabCase);
const TypeChecker _jsonSnakeChecker = TypeChecker.typeNamed(JsonSnakeCase);
const TypeChecker _nameChecker = TypeChecker.typeNamed(JsonName);
const TypeChecker _ignoreChecker = TypeChecker.typeNamed(JsonIgnore);
const TypeChecker _convertChecker = TypeChecker.typeNamed(JsonConvert);

extension ClassElementX on ClassElement {
  String get cleanName {
    // hack to fix freezed names
    if (displayName.startsWith(r'_$') && displayName.endsWith('Impl')) {
      return displayName
          .substring(0, name!.length - 4) // remove Impl
          .replaceFirst(r'_$', ''); // remove _$
    }

    return displayName;
  }

  List<PropertyInducingElement> get allAccessors {
    final accessorNames = <String>{};
    return [
          ...getters.map((e) => e.variable),
          ...setters.map((e) => e.variable),
          for (final supertype in allSupertypes) ...[
            if (!supertype.isDartCoreObject)
              ...supertype.element.getters.map((e) => e.variable),
            if (!supertype.isDartCoreObject)
              ...supertype.element.setters.map((e) => e.variable),
          ],
        ]
        .where(
          (e) =>
              e.isPublic &&
              !e.isStatic &&
              !e.jsonIgnore &&
              accessorNames.add(e.name!),
        )
        .toList();
  }

  ConstructorElement get jsonConstructor {
    return constructors.firstWhere(
      (e) => e.name == 'new',
      orElse: () => err('No default constructor found', this),
    );
  }

  bool hasFromConstructor(String name, String param) {
    bool check(InterfaceType t, String name, String param) {
      for (final c in t.constructors) {
        if (c.name == name && c.formalParameters.length == 1) {
          final posParam = c.formalParameters.firstWhere((e) => e.isPositional);
          if (posParam.type.toString() == param) {
            return true;
          }
        }
      }
      return false;
    }

    // check if it's freezed class starting with _$_
    if (isPrivate && displayName.startsWith(r'_$_')) {
      // find super Type with == cleanName
      final superType = allSupertypes.firstWhere((e) {
        final display = e.getDisplayString();
        return display == cleanName;
      });
      // check for constructor
      return check(superType, name, param);
    } else {
      return check(thisType, name, param);
    }
  }

  FormalParameterElement? constructorParam(String name) {
    for (final param in jsonConstructor.formalParameters) {
      if (param.name == name) {
        return param;
      }
    }
    return null;
  }

  String? defaultValue(String name) {
    return constructorParam(name)?.defaultValueCode;
  }
}

extension DartTypeX on DartType {
  bool get hasJsonAnnotation {
    return _jsonChecker.hasAnnotationOf(element!.nonSynthetic);
  }

  bool get isNullable {
    return nullabilitySuffix == NullabilitySuffix.question ||
        this is DynamicType;
  }

  bool get hasFromCrimsonConstructor {
    final el = element;
    if (el is ClassElement) {
      return el.hasFromConstructor('fromCrimson', 'Crimson');
    } else {
      return false;
    }
  }

  DartType get listParam {
    return (this as ParameterizedType).typeArguments.first;
  }

  DartType get mapParam {
    return (this as ParameterizedType).typeArguments.last;
  }
}

extension PropertyInducingElementX on PropertyInducingElement {
  String get jsonName {
    final ann = _nameChecker.firstAnnotationOfExact(nonSynthetic);
    final annName = ann?.getField('name')?.toStringValue();
    if (annName != null) {
      return annName;
    }

    final separator =
        _jsonKebabChecker.hasAnnotationOf(enclosingElement!)
            ? '-'
            : _jsonSnakeChecker.hasAnnotationOf(enclosingElement!)
            ? '_'
            : null;
    if (separator != null) {
      return name!.splitMapJoin(
        RegExp('([A-Z])'),
        onMatch: (m) => '$separator${m.group(1)!.toLowerCase()}',
        onNonMatch: (s) => s,
      );
    } else {
      return name!;
    }
  }

  Set<String> get jsonAliases {
    final ann = _nameChecker.firstAnnotationOfExact(nonSynthetic);
    return ann
            ?.getField('aliases')
            ?.toSetValue()
            ?.map((e) => e.toStringValue()!)
            .toSet() ??
        {};
  }

  bool get jsonIgnore {
    final ann = _ignoreChecker.firstAnnotationOfExact(nonSynthetic);
    return ann != null ||
        {'hashCode', 'runtimeType', 'copyWith'}.contains(name);
  }

  ExecutableElement? get fromJson {
    final ann = _convertChecker.firstAnnotationOf(nonSynthetic);
    return ann?.getField('fromJson')?.toFunctionValue();
  }

  ExecutableElement? get toJson {
    final ann = _convertChecker.firstAnnotationOf(nonSynthetic);
    return ann?.getField('toJson')?.toFunctionValue();
  }
}

extension ExecutableElementX on ExecutableElement {
  String get qualifiedName {
    if (this is TopLevelFunctionElement) {
      return name!;
    }

    if (this is MethodElement) {
      final method = this as MethodElement;
      return '${method.enclosingElement!.name}.${method.name}';
    }

    if (this is ConstructorElement) {
      final constructor = this as ConstructorElement;
      // Ignore the default constructor.
      if (constructor.name == 'new') {
        return '${constructor.enclosingElement.name}';
      }
      return '${constructor.enclosingElement.name}.${constructor.name}';
    }

    throw UnsupportedError('Not sure how to support typeof $runtimeType');
  }
}

Never err(String msg, [Element? element]) {
  throw InvalidGenerationSourceError(msg, element: element);
}
