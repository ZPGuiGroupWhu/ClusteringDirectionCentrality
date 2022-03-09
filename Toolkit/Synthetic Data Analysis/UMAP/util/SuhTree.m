%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef SuhTree < handle
    properties
        tree; %uitree instance
        jtree; %javax.swing.JTree instance
        props;
        fncNewChildren;
        fncGetChildren;
        fncNodeExists;
        fncGetPath;
        uiNodes;
        root;
        remembered=false;
        container;
    end
    
    methods
        function this=SuhTree(tree, container, root, fncGetPath, ...
                fncNodeExists, fncNewChildren, fncGetChildren)
            this.tree=tree;
            this.root=root;
            this.container=container;
            this.jtree=handle(tree.getTree,'CallbackProperties');
            this.fncNodeExists=fncNodeExists;
            this.fncGetPath=fncGetPath;
            this.fncNewChildren=fncNewChildren;
            this.fncGetChildren=fncGetChildren;
            this.uiNodes=java.util.TreeMap;
            this.jtree.setToggleClickCount(0);
            this.setMultipleSelection;
        end
        
        function setMultipleSelection(this,yes)
            if nargin<2
                this.tree.setMultipleSelectionEnabled(true)
            else
                this.tree.setMultipleSelectionEnabled(yes)
            end
        end
        function rememberNodes(this, uiNode)
            if nargin<2
                uiNode=this.root;
            end
            key=uiNode.getValue;
            this.uiNodes.put(java.lang.String(key), uiNode);
            N=uiNode.getChildCount();
            for j=1:N
                this.rememberNodes(uiNode.getChildAt(j-1));
            end
        end
        
        function uiNode=ensureVisible(this, id, selectIf1MutliIf2, scroll, ...
                javaBag4Paths)
            if nargin<5
                javaBag4Paths=[];
                if nargin<4
                    scroll=true;
                    if nargin<3
                        selectIf1MutliIf2=0;
                    end
                end
            end
            if isempty(id)
                uiNode=[];
                return;
            end
            if ~this.remembered
                this.rememberNodes;
                this.remembered=true;
            end
            if ~feval(this.fncNodeExists, id)
                uiNode=[];
                warning('tree id="%s" NOT known outside of uitree...', id);
                return;
            end
            select=selectIf1MutliIf2>0;
            isMultiSelect=selectIf1MutliIf2==2;
            [inView, ~, uiNode]=SuhTree.IsInViewPort( this, id);
            if inView
                if select 
                    this.doSelection(isMultiSelect, uiNode);
                end
            else
                ok=true;
                ids=feval(this.fncGetPath, id);
                N=length(ids);
                uiNode=this.root;
                this.expandNode(uiNode);
                for i=1:N
                    cur=ids{i};
                    N2=uiNode.getChildCount();
                    ok=false;
                    for j=1:N2
                        child=uiNode.getChildAt(j-1);
                        childId=child.getValue;
                        if strcmp(childId, cur)
                            ok=true;
                            uiNode=child;
                            if i<N
                                this.expandNode(uiNode);
                            end
                            break;
                        end
                    end
                    if ~ok
                        break;
                    end
                end
                if ~ok
                    uiNode=[];
                    warning('tree id="%s" IS known outside of uitree but NOT inside...', id);
                elseif select 
                    this.doSelection(isMultiSelect, uiNode);
                end
                %DON'T jam it at the bottom of the window with the LEAST
                %visibility
                if nargin<4 || scroll
                    pp=uiNode.getPath;
                    tp=javax.swing.tree.TreePath(pp);
                    this.jtree.scrollPathToVisible(tp);
                    scrollUiNode=uiNode.getNextNode;
                    if ~isempty(scrollUiNode)
                        pp=scrollUiNode.getPath;
                        tp=javax.swing.tree.TreePath(pp);
                        this.jtree.scrollPathToVisible(tp);
                    end
                    drawnow;
                end
            end   
            if ~isempty(uiNode) && isjava(javaBag4Paths)
                tp=javax.swing.tree.TreePath(uiNode.getPath);
                javaBag4Paths.add(tp);
            end
        end
        
        function doSelection(this, isMultiSelect, uiNode)
            if isMultiSelect
                tp=javax.swing.tree.TreePath(uiNode.getPath);
                this.jtree.addSelectionPath(tp);                
            else
                this.tree.setSelectedNode(uiNode);
            end
        end
        
        function expandNode(this, uiNode)
            this.ensureChildUiNodesExist(uiNode);
            if ~uiNode.isLeafNode()
                this.tree.expand(uiNode);
            end
        end
        
        function ok=ensureChildUiNodesExist(this, uiNode)
            uiN=uiNode.getChildCount();
            id=uiNode.getValue;
            children=feval(this.fncGetChildren, id);
            nonUiN=length(children);
            if uiN~=nonUiN
                if uiNode.isLeafNode
                    uiNode.setLeafNode(false);
                end
                uiChildren=feval(this.fncNewChildren, id);
                for i=1:nonUiN
                    uiChild=uiChildren(i);
                    this.uiNodes.put(java.lang.String(children{i}), uiChild);
                    uiNode.add(uiChild);
                end
                this.tree.reloadNode(uiNode);
                this.tree.setLoaded(uiNode,true);
            end
        end
        
        function stylize(this, fontName)
            if nargin<2
                fontName='Arial';
            end
            jt=this.jtree;
            jt.setRowHeight(0);
            f=jt.getFont;
            jt.setFont( java.awt.Font(fontName, f.getStyle, f.getSize-1));
            jt.setBorder(javax.swing.BorderFactory.createEmptyBorder (12,12,12,12));
            jt.setRowHeight(0);
        end
        
    end
    
    methods(Static)
        function this=New(root, fncNodeSelected, fncGetPath, fncNodeExists, ...
                fncNewChildren, fncGetChildren)
            [uit, container] = uitree('v0','Root',  root, ...
                'SelectionChangeFcn',fncNodeSelected);
            this=SuhTree(uit, container, root, fncGetPath, ...
                fncNodeExists, fncNewChildren, fncGetChildren);
        end
        
        function [ok, selected, uiNode, row]=IsInViewPort(this, id)
            ok=false;
            row=0;
            selected=false;
            uiNode=this.uiNodes.get(java.lang.String(id));
            if isempty(uiNode)
                return;
            end
            tr=this.jtree;
            vp=javaObjectEDT(tr.getParent);
            vr=javaObjectEDT(vp.getViewRect);
            firstRow=tr.getClosestRowForLocation( vr.x, vr.y);
        	lastRow=tr.getClosestRowForLocation(vr.x, vr.y + vr.height);   
            for i=firstRow+1:lastRow-1
                path=javaObjectEDT(tr.getPathForRow(i));
                uiNode=path.getLastPathComponent;
                id1=uiNode.getValue;
                if strcmp(id, id1)
                    ok=true;
                    selected=tr.isRowSelected(i);
                    row=i;
                    return;
                end
            end
        end
    end
end