/*******************************************************************************
 * Copyright (c) 2011 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.eclipse.xtext.serializer.impl;

import java.io.IOException;
import java.io.Writer;
import java.util.Iterator;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.formatting.IFormatter;
import org.eclipse.xtext.nodemodel.ICompositeNode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;
import org.eclipse.xtext.parsetree.reconstr.ITokenStream;
import org.eclipse.xtext.parsetree.reconstr.impl.TokenStringBuffer;
import org.eclipse.xtext.parsetree.reconstr.impl.WriterTokenStream;
import org.eclipse.xtext.resource.SaveOptions;
import org.eclipse.xtext.serializer.IRecursiveSequencer;
import org.eclipse.xtext.serializer.ISemanticSequencer;
import org.eclipse.xtext.serializer.ISerializer;
import org.eclipse.xtext.serializer.acceptor.IRecursiveSequenceAcceptor;
import org.eclipse.xtext.serializer.acceptor.TokenStreamSequenceAdapter;
import org.eclipse.xtext.serializer.diagnostic.ISerializationDiagnostic;
import org.eclipse.xtext.util.EmfFormatter;
import org.eclipse.xtext.util.ReplaceRegion;

import com.google.inject.Inject;

/**
 * @author Moritz Eysholdt - Initial contribution and API
 */
public class Serializer implements ISerializer {

	public String serialize(EObject obj) {
		return serialize(obj, SaveOptions.defaultOptions());
	}

	@Inject
	protected IFormatter formatter;

	@Inject
	protected IRecursiveSequencer sequencer;

	@Inject
	protected ISemanticSequencer semanticSequencer;

	protected void serialize(EObject obj, ITokenStream tokenStream, SaveOptions options) throws IOException {
		ISerializationDiagnostic.Acceptor errors = ISerializationDiagnostic.EXCEPTION_THROWING_ACCEPTOR;
		ITokenStream formatterTokenStream = formatter.createFormatterStream(null, tokenStream, !options.isFormatting());
		Iterator<EObject> context = semanticSequencer.findContexts(obj, null).iterator();
		if (!context.hasNext())
			throw new RuntimeException("No Context for " + EmfFormatter.objPath(obj) + " could be found");
		IRecursiveSequenceAcceptor acceptor = new TokenStreamSequenceAdapter(formatterTokenStream, errors);
		sequencer.createSequence(context.next(), obj, acceptor, errors);
		formatterTokenStream.flush();
	}

	public String serialize(EObject obj, SaveOptions options) {
		TokenStringBuffer tokenStringBuffer = new TokenStringBuffer();
		try {
			serialize(obj, tokenStringBuffer, options);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		return tokenStringBuffer.toString();
	}

	public void serialize(EObject obj, Writer writer, SaveOptions options) throws IOException {
		serialize(obj, new WriterTokenStream(writer), options);
	}

	public ReplaceRegion serializeReplacement(EObject obj, SaveOptions options) {
		ICompositeNode node = NodeModelUtils.findActualNodeFor(obj);
		String text = serialize(obj);
		return new ReplaceRegion(node.getTotalOffset(), node.getTotalLength(), text);
	}

}