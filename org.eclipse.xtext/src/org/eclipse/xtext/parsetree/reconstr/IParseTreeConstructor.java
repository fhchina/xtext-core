/*******************************************************************************
 * Copyright (c) 2008 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 *******************************************************************************/
package org.eclipse.xtext.parsetree.reconstr;

import java.io.IOException;
import java.util.List;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.parsetree.reconstr.impl.TreeConstructionReportImpl;
import org.eclipse.xtext.util.ITextRegion;

import com.google.inject.ImplementedBy;

/**
 * @author Sven Efftinge - Initial contribution and API
 * @author Moritz Eysholt
 */
public interface IParseTreeConstructor {

	interface TreeConstructionDiagnostic {
		EObject getEObject();

		String getLikelyErrorReasons();
	}

	@ImplementedBy(TreeConstructionReportImpl.class)
	interface TreeConstructionReport {
		List<TreeConstructionDiagnostic> getDiagnostics();

		boolean isSuccess();

		ITextRegion getPreviousLocation();
	}

	TreeConstructionReport serializeSubtree(EObject object, ITokenStream out) throws IOException;

}
