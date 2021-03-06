/**
 * Copyright (c) 2016 TypeFox GmbH (http://www.typefox.io) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package org.eclipse.xtext.ide.tests.editor.contentassist;

import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import java.util.Map;
import java.util.concurrent.Executors;
import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtend.lib.annotations.Accessors;
import org.eclipse.xtend2.lib.StringConcatenation;
import org.eclipse.xtext.AbstractElement;
import org.eclipse.xtext.ParserRule;
import org.eclipse.xtext.grammaranalysis.impl.GrammarElementTitleSwitch;
import org.eclipse.xtext.ide.editor.contentassist.ContentAssistContext;
import org.eclipse.xtext.ide.editor.contentassist.antlr.ContentAssistContextFactory;
import org.eclipse.xtext.resource.FileExtensionProvider;
import org.eclipse.xtext.resource.IResourceFactory;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.testing.validation.ValidationTestHelper;
import org.eclipse.xtext.util.StringInputStream;
import org.eclipse.xtext.util.TextRegion;
import org.eclipse.xtext.xbase.lib.CollectionLiterals;
import org.eclipse.xtext.xbase.lib.Conversions;
import org.eclipse.xtext.xbase.lib.Exceptions;
import org.eclipse.xtext.xbase.lib.IterableExtensions;
import org.eclipse.xtext.xbase.lib.Pair;
import org.eclipse.xtext.xbase.lib.Pure;

/**
 * @author Moritz Eysholdt - Initial contribution and API
 */
@SuppressWarnings("all")
public class ContentAssistContextTestHelper {
  @Inject
  private FileExtensionProvider fileExtension;
  
  @Inject
  private IResourceFactory resFactory;
  
  @Inject
  private ValidationTestHelper validator;
  
  @Accessors
  private String document;
  
  @Accessors
  private ParserRule entryPoint;
  
  @Accessors
  private String cursor = "<|>";
  
  private XtextResource parse(final String doc) {
    try {
      String _primaryFileExtension = this.fileExtension.getPrimaryFileExtension();
      String _plus = ("dummy." + _primaryFileExtension);
      final URI uri = URI.createURI(_plus);
      Resource _createResource = this.resFactory.createResource(uri);
      final XtextResource res = ((XtextResource) _createResource);
      XtextResourceSet _xtextResourceSet = new XtextResourceSet();
      EList<Resource> _resources = _xtextResourceSet.getResources();
      _resources.add(res);
      if ((this.entryPoint != null)) {
        res.setEntryPoint(this.entryPoint);
      }
      StringInputStream _stringInputStream = new StringInputStream(doc);
      Map<Object, Object> _emptyMap = CollectionLiterals.<Object, Object>emptyMap();
      res.load(_stringInputStream, _emptyMap);
      this.validator.assertNoErrors(res);
      return res;
    } catch (Throwable _e) {
      throw Exceptions.sneakyThrow(_e);
    }
  }
  
  public String firstSetGrammarElementsToString(final ContentAssistContextFactory factory) {
    final int offset = this.document.indexOf(this.cursor);
    Preconditions.checkArgument((offset >= 0), "you forgot to provide a cursor");
    final String doc = this.document.replace(this.cursor, "");
    final XtextResource res = this.parse(doc);
    factory.setPool(Executors.newCachedThreadPool());
    TextRegion _textRegion = new TextRegion(0, 0);
    final ContentAssistContext[] ctxs = factory.create(doc, _textRegion, offset, res);
    GrammarElementTitleSwitch _grammarElementTitleSwitch = new GrammarElementTitleSwitch();
    GrammarElementTitleSwitch _showAssignments = _grammarElementTitleSwitch.showAssignments();
    GrammarElementTitleSwitch _showQualified = _showAssignments.showQualified();
    final GrammarElementTitleSwitch f = _showQualified.showRule();
    StringConcatenation _builder = new StringConcatenation();
    {
      Iterable<Pair<Integer, ContentAssistContext>> _indexed = IterableExtensions.<ContentAssistContext>indexed(((Iterable<? extends ContentAssistContext>)Conversions.doWrapArray(ctxs)));
      for(final Pair<Integer, ContentAssistContext> ctx : _indexed) {
        _builder.append("context");
        Integer _key = ctx.getKey();
        _builder.append(_key);
        _builder.append(" {");
        _builder.newLineIfNotEmpty();
        {
          ContentAssistContext _value = ctx.getValue();
          ImmutableList<AbstractElement> _firstSetGrammarElements = _value.getFirstSetGrammarElements();
          for(final AbstractElement ele : _firstSetGrammarElements) {
            _builder.append("\t");
            EClass _eClass = ele.eClass();
            String _name = _eClass.getName();
            _builder.append(_name, "\t");
            _builder.append(": ");
            String _apply = f.apply(ele);
            _builder.append(_apply, "\t");
            _builder.newLineIfNotEmpty();
          }
        }
        _builder.append("}");
        _builder.newLine();
      }
    }
    return _builder.toString();
  }
  
  @Pure
  public String getDocument() {
    return this.document;
  }
  
  public void setDocument(final String document) {
    this.document = document;
  }
  
  @Pure
  public ParserRule getEntryPoint() {
    return this.entryPoint;
  }
  
  public void setEntryPoint(final ParserRule entryPoint) {
    this.entryPoint = entryPoint;
  }
  
  @Pure
  public String getCursor() {
    return this.cursor;
  }
  
  public void setCursor(final String cursor) {
    this.cursor = cursor;
  }
}
