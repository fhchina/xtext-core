/**
 * Copyright (c) 2015 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 */
package org.eclipse.xtext.ide.editor.contentassist;

import com.google.common.base.Predicate;
import com.google.inject.Inject;
import org.apache.log4j.Logger;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.xtend.lib.annotations.AccessorType;
import org.eclipse.xtend.lib.annotations.Accessors;
import org.eclipse.xtext.CrossReference;
import org.eclipse.xtext.ide.editor.contentassist.ContentAssistContext;
import org.eclipse.xtext.ide.editor.contentassist.ContentAssistEntry;
import org.eclipse.xtext.ide.editor.contentassist.IIdeContentProposalAcceptor;
import org.eclipse.xtext.ide.editor.contentassist.IdeContentProposalCreator;
import org.eclipse.xtext.ide.editor.contentassist.IdeContentProposalPriorities;
import org.eclipse.xtext.naming.IQualifiedNameConverter;
import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.xbase.lib.Exceptions;
import org.eclipse.xtext.xbase.lib.Procedures.Procedure1;
import org.eclipse.xtext.xbase.lib.Pure;

/**
 * Special content assist proposal provider for cross-references.
 * @noreference
 */
@SuppressWarnings("all")
public class IdeCrossrefProposalProvider {
  private final static Logger LOG = Logger.getLogger(IdeCrossrefProposalProvider.class);
  
  @Accessors(AccessorType.PROTECTED_GETTER)
  @Inject
  private IQualifiedNameConverter qualifiedNameConverter;
  
  @Accessors(AccessorType.PROTECTED_GETTER)
  @Inject
  private IdeContentProposalCreator proposalCreator;
  
  @Inject
  private IdeContentProposalPriorities proposalPriorities;
  
  public void lookupCrossReference(final IScope scope, final CrossReference crossReference, final ContentAssistContext context, final IIdeContentProposalAcceptor acceptor, final Predicate<IEObjectDescription> filter) {
    try {
      Iterable<IEObjectDescription> _queryScope = this.queryScope(scope, crossReference, context);
      for (final IEObjectDescription candidate : _queryScope) {
        {
          boolean _canAcceptMoreProposals = acceptor.canAcceptMoreProposals();
          boolean _not = (!_canAcceptMoreProposals);
          if (_not) {
            return;
          }
          boolean _apply = filter.apply(candidate);
          if (_apply) {
            final ContentAssistEntry entry = this.createProposal(candidate, crossReference, context);
            int _crossRefPriority = this.proposalPriorities.getCrossRefPriority(candidate, entry);
            acceptor.accept(entry, _crossRefPriority);
          }
        }
      }
    } catch (final Throwable _t) {
      if (_t instanceof UnsupportedOperationException) {
        final UnsupportedOperationException uoe = (UnsupportedOperationException)_t;
        IdeCrossrefProposalProvider.LOG.error("Failed to create content assist proposals for cross-reference.", uoe);
      } else {
        throw Exceptions.sneakyThrow(_t);
      }
    }
  }
  
  protected Iterable<IEObjectDescription> queryScope(final IScope scope, final CrossReference crossReference, final ContentAssistContext context) {
    return scope.getAllElements();
  }
  
  protected ContentAssistEntry createProposal(final IEObjectDescription candidate, final CrossReference crossRef, final ContentAssistContext context) {
    QualifiedName _name = candidate.getName();
    String _string = this.qualifiedNameConverter.toString(_name);
    final Procedure1<ContentAssistEntry> _function = (ContentAssistEntry it) -> {
      it.setSource(candidate);
      EClass _eClass = candidate.getEClass();
      String _name_1 = null;
      if (_eClass!=null) {
        _name_1=_eClass.getName();
      }
      it.setDescription(_name_1);
    };
    return this.proposalCreator.createProposal(_string, context, _function);
  }
  
  @Pure
  protected IQualifiedNameConverter getQualifiedNameConverter() {
    return this.qualifiedNameConverter;
  }
  
  @Pure
  protected IdeContentProposalCreator getProposalCreator() {
    return this.proposalCreator;
  }
}