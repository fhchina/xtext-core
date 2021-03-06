/**
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package org.eclipse.xtext.ide.tests.testlanguage.coloring;

import com.google.common.collect.ImmutableList;
import java.util.Collections;
import java.util.List;
import java.util.function.Consumer;
import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.lsp4j.ColoringInformation;
import org.eclipse.lsp4j.ColoringStyle;
import org.eclipse.lsp4j.Position;
import org.eclipse.lsp4j.Range;
import org.eclipse.xtext.ide.server.Document;
import org.eclipse.xtext.ide.server.coloring.IColoringService;
import org.eclipse.xtext.ide.tests.testlanguage.testLanguage.Operation;
import org.eclipse.xtext.ide.tests.testlanguage.testLanguage.Property;
import org.eclipse.xtext.ide.tests.testlanguage.testLanguage.TestLanguagePackage;
import org.eclipse.xtext.nodemodel.INode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.xbase.lib.CollectionLiterals;
import org.eclipse.xtext.xbase.lib.IteratorExtensions;
import org.eclipse.xtext.xbase.lib.Procedures.Procedure1;

/**
 * Basic coloring service that highlights the method and variable declarations
 * for testing purposes.
 * 
 * @author akos.kitta - Initial contribution and API
 */
@SuppressWarnings("all")
public class ColoringServiceImpl implements IColoringService {
  private final static List<Integer> STYLE_IDS = Collections.<Integer>singletonList(Integer.valueOf(ColoringStyle.Identifier));
  
  @Override
  public List<? extends ColoringInformation> getColoring(final XtextResource resource, final Document document) {
    if ((resource == null)) {
      return CollectionLiterals.<ColoringInformation>emptyList();
    }
    final ImmutableList.Builder<ColoringInformation> builder = ImmutableList.<ColoringInformation>builder();
    TreeIterator<Object> _allContents = EcoreUtil.<Object>getAllContents(resource, true);
    final Procedure1<Object> _function = (Object it) -> {
      List<INode> _xifexpression = null;
      if ((it instanceof Property)) {
        _xifexpression = NodeModelUtils.findNodesForFeature(((EObject)it), TestLanguagePackage.Literals.MEMBER__NAME);
      } else {
        List<INode> _xifexpression_1 = null;
        if ((it instanceof Operation)) {
          _xifexpression_1 = NodeModelUtils.findNodesForFeature(((EObject)it), TestLanguagePackage.Literals.MEMBER__NAME);
        } else {
          _xifexpression_1 = CollectionLiterals.<INode>emptyList();
        }
        _xifexpression = _xifexpression_1;
      }
      final List<INode> nodes = _xifexpression;
      final Consumer<INode> _function_1 = (INode it_1) -> {
        final int start = it_1.getOffset();
        int _offset = it_1.getOffset();
        int _length = it_1.getLength();
        final int end = (_offset + _length);
        Position _position = document.getPosition(start);
        Position _position_1 = document.getPosition(end);
        final Range range = new Range(_position, _position_1);
        ColoringInformation _coloringInformation = new ColoringInformation(range, ColoringServiceImpl.STYLE_IDS);
        builder.add(_coloringInformation);
      };
      nodes.forEach(_function_1);
    };
    IteratorExtensions.<Object>forEach(_allContents, _function);
    return builder.build();
  }
}
